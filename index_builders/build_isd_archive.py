import boto3
import duckdb
import tempfile
import logging
from botocore import UNSIGNED
from botocore.config import Config

logging.basicConfig(level=logging.INFO,format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)



def get_object_keys(s3_client, bucket_name, start_year, end_year):
    for year in range(start_year, end_year):
        logging.info(f'walking station files in {str(year)}')
        try:
            # Use list_objects_v2 to fetch the bucket contents
            paginator = s3_client.get_paginator('list_objects_v2')
            page_iterator = paginator.paginate(Bucket=bucket_name, Prefix=str(year))
            for page in page_iterator:
                if 'Contents' not in page:
                    continue
            
                for obj in page['Contents']:
                    yield obj['Key']
        except Exception as e:
            print(f"Error fetching bucket contents: {e}")

def main():
    s3_client = boto3.client('s3', config=Config(signature_version=UNSIGNED))
    with tempfile.NamedTemporaryFile(delete=True) as tmp_file:
        all_keys = list(get_object_keys(s3_client, 'noaa-global-hourly-pds', 2022, 2023))
        tmp_file.write('\n'.join(all_keys).encode('utf-8'))
        connection = duckdb.connect('ndbc.db')
        connection.install_extension('spatial')
        connection.load_extension('spatial')
        connection.sql(f"""
            COPY (
                WITH 
                years_idx as 
                    (SELECT * as archive_file from read_csv('{tmp_file.name}', header=false)),
                joinable_years_idx as
                    (SELECT archive_file[6:-5] as station, archive_file FROM years_idx),
                known_stations as 
                    (SELECT usaf_id || wban_num as station, ST_QuadKey(st_geomfromwkb(geometry),6) as quadkey
                     FROM isd_duck.weather_stations)
                SELECT
                    (archive_file[:4] || '-01-01T00:00:00Z')::timestamptz as timestamp_tz,
                    quadkey,
                    's3://noaa-global-hourly-pds/' || archive_file as archive_url
                FROM known_stations 
                INNER JOIN joinable_years_idx ON joinable_years_idx.station=known_stations.station
                ORDER BY timestamp_tz, quadkey
            ) TO 'data/isd.archive.parquet'
        """)

if __name__ == '__main__':
    main()
