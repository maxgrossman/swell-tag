import os
import itertools

from archive_builders.common import setup
from archive_builders.common import lambda_duck as duckdb
from bronze.constants import EVENT_TO_ARCHIVE_FUNCS, SHARED_ARCHIVE_FUNCS


S3_BUCKET = os.getenv("SWELL_TAGS_BUCKET")

if not S3_BUCKET:
    raise EnvironmentError("I NEED A CONFIGURED SWELL TAGS BUCKET")

def handler(event, context):
    archives = event.get('archives', ['ushlc', 'ndbc', 'era5'])
    with duckdb.connect() as connection:
        setup(connection)

        archive_funcs = [EVENT_TO_ARCHIVE_FUNCS.get(archive) for archive in archives]
        archive_funcs = list(itertools.chain.from_iterable(archive_funcs)) + SHARED_ARCHIVE_FUNCS

        for archive_func, func_output in archive_funcs:
            archive_func(connection, f'{S3_BUCKET}/bronze/{func_output}')

        return [{'archive': archive} for archive in archives]


