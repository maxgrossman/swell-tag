import boto3
import duckdb
import tempfile
import logging
from botocore import UNSIGNED
from botocore.config import Config

logging.basicConfig(level=logging.INFO,format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)



def get_object_keys(s3_client, bucket_name, start_year, end_year, object_filter):
    for year in range(start_year, end_year):
        logging.info(f'walking station files in {str(year)}')
        try:
            # Use list_objects_v2 to fetch the bucket contents
            paginator = s3_client.get_paginator('list_objects_v2')
            page_iterator = paginator.paginate(Bucket=bucket_name, Prefix=f'e5.oper.an.sfc/{str(year)}')
            for page in page_iterator:
                if 'Contents' not in page:
                    continue
            
                for obj in page['Contents']:
                    if object_filter(obj) == False:
                        continue
                    yield obj['Key']
        except Exception as e:
            print(f"Error fetching bucket contents: {e}")

def main():
    s3_client = boto3.client('s3', config=Config(signature_version=UNSIGNED))
    with tempfile.NamedTemporaryFile(delete=True) as tmp_file:
        all_keys = list(get_object_keys(s3_client, 'nsf-ncar-era5', 2022, 2023, lambda obj: '_10v' in obj['Key'] or '_10u' in obj['Key']))
        tmp_file.write('\n'.join(all_keys).encode('utf-8'))
        tmp_file.seek(0)
        connection = duckdb.connect()
        connection.sql(f"""
            COPY (
                WITH era_index as (SELECT * as archive_file from read_csv('{tmp_file.name}', header=false))
                SELECT
                    strptime(archive_file[-24:-15], '%Y%m%d%H')::timestamptz at time zone 'utc' as start_timestamp_tz,
                    strptime(archive_file[-13:-4], '%Y%m%d%H')::timestamptz at time zone 'utc' as end_timestamp_tz,
                    's3://nsf-ncar-era5/e5.oper.an.sfc/' || archive_file as archive_url,
                    regexp_replace(string_split(archive_file,'/')[-1], 'nc', 'parquet') as parquet_path
                FROM era_index
            ) TO 'data/era5.10uv.archive.csv'
        """)

if __name__ == '__main__':
    main()
