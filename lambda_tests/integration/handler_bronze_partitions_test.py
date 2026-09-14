import pytest
import duckdb
import os
import boto3

from archive_builders.common import setup
from bronze.era5_cells import build_bronze_partitions

s3_client = boto3.client('s3')

def test_era5_cells_partitions():
    s3_bucket = 's3://swell-tags-us-west-2'
    os.environ['DUCKDB_EXTENSIONS_DIRECTORY'] = '~/.duckdb/extensions'
    with duckdb.connect() as conn:
        conn.install_extension('httpfs')
        conn.install_extension('aws')
        setup(conn)
        res = build_bronze_partitions(conn, s3_bucket, 80)
        print(res)