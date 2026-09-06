import os

from archive_builders.build_ndbc_archive import write_standard_met_to_s3
from archive_builders.build_ushlc_archive import write_uh_slc_to_s3
from archive_builders.build_era5_archive import write_era5_to_s3
from archive_builders.build_coast_data import write_coast_h3s_to_s3, write_coast_lookups_to_s3, write_wgs84_coast_to_s3
from archive_builders.common import setup
from archive_builders.common import lambda_duck as duckdb
from bronze.constants import EVENT_TO_PART_MAP



S3_BUCKET = os.getenv("ARCHIVE_S3_BUCKET", "s3://swell-tags")

def handler(event, context):
    with duckdb.connect() as connection:
        setup(connection)
        write_standard_met_to_s3(connection, f'{S3_BUCKET}/bronze/ndbc_archive.csv')
        write_uh_slc_to_s3(connection, f'{S3_BUCKET}/bronze/ushlc_archive.csv')
        write_era5_to_s3(connection, f'{S3_BUCKET}/bronze/era5_archive.csv')
        write_wgs84_coast_to_s3(connection, f'{S3_BUCKET}/bronze/coast_lines.parquet')
        write_coast_lookups_to_s3(connection, f'{S3_BUCKET}/bronze/coast_lookups.parquet')
        write_coast_h3s_to_s3(connection, f'{S3_BUCKET}/bronze/coast_h3s.parquet')

        return [{'archive': key} for key in EVENT_TO_PART_MAP.keys()]


