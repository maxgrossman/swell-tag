import boto3
import pandas as pd

from bronze.common import build_parititon_query

ARCHIVE_QUERY = f"""
    SELECT archive_url, s3_url from read_csv($ushlc_archive)
    WHERE list_contains($partition, archive_url)
"""

BRONZE_SQL_DOWNLOAD = f"""
COPY (
    select
        filename,
        filename[-8:-6] as uh_id, 
        filename[-5] as version,
        make_timestamptz(column0::bigint,column1::bigint,column2::bigint,column3::bigint,0::bigint,0.0,'utc') as timestamp_tz, 
        column4 as reading_mm 
    from read_csv($archive_urls)
) TO $parquet_s3_path (FORMAT PARQUET, PARTITION_BY (uh_id), APPEND true)
"""


def build_bronze_layer(conn, s3_bucket, partition):
    ushlc_archive = s3_bucket + '/bronze/ushlc_archive.csv'
    archive_info = conn.execute(ARCHIVE_QUERY, {'ushlc_archive': ushlc_archive, 'partition': partition}).df()
    archive_urls = list(archive_info['archive_url'])
    parquet_s3_path = s3_bucket + '/bronze/raw/ushlc/'
    conn.execute(BRONZE_SQL_DOWNLOAD, {
        'archive_urls': archive_urls,
        'parquet_s3_path': parquet_s3_path
    })

def build_bronze_partitions(conn, s3_bucket, num_tiles) -> pd.DataFrame:
    query, args = build_parititon_query(s3_bucket,num_tiles,'ushlc', 'uh_id')
    return conn.execute(query, args).df()