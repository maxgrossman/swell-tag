import os
import duckdb

from itertools import batched

SWELL_TAGS_DB = os.getenv("SWELL_TAGS_DB")

def handler(event, context):
    # go find the archive urls that map to a month i do not yet have in swelltags.
    with duckdb.connect(SWELL_TAGS_DB) as conn:
        new_archives = conn.sql("""
            with loaded_era5_months as (
                select distinct date_trunc('month', timestamp_tz) as loaded_month 
                from era5_duck.wind
            ), 
            -- 'left join' will make anything not in the wind table show loaded month 'null'
            -- so can use that to figure out if month is loaded already.
            loaded_archive_matched as (
                select archive_url, parquet_path, loaded_month,
                       case when regexp_matches(archive_url, '10u') then 'VAR_10U' else 'VAR_10V' end as era5_wind_dim
                from era5_duck.archive
                left join loaded_era5_months on date_trunc('month', start_timestamp_tz) = loaded_month
            )
            select archive_url, parquet_path, era5_wind_dim 
            from loaded_archive_matched where loaded_month is null;
        """).df()

        backfill_zipped = zip(new_archives['archive_url'], new_archives['parquet_path'], new_archives['era5_wind_dim'])
        backfill_batches = list(batched(backfill_zipped, 5))
        return { 'era5_to_backfill': backfill_batches }