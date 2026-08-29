import duckdb
import boto3
import tempfile
import os
from era5_wind_to_parquet import era5_10_vectors_to_table

def handler(event, context):
    with tempfile.TemporaryDirectory() as tmp_dir:
        # read the archive file; load all the files into our own s3bucket
        archive_urls = duckdb.sql(f"""
        install httpfs; load httpfs;
        install aws; load aws;
        -- how do this w/lambda?
        create secret (type s3, provider credential_chain);
        select 
            case when '10u' in archive_url then 'VAR_10U' else 'VAR_10V' end as era5_wind_dim,
            parquet_path,
            archive_url 
        from read_csv_auto({event.get('era5_archive')});
        """).to_df()

        # copy the coast mask and look ups to the temp dir we in right now!
        coast_bucket = event.get('coast_bucket')
        coast_mask = event.get('coast_mask')
        cells_lookup = event.get('cells_lookup')
        coast_mask_path, cells_lookup_path = [os.path.join(tmp_dir, input_file) for input_file in (coast_mask, cells_lookup)]

        s3_client = boto3.client('s3')
        s3_client.download_file(coast_bucket, coast_mask, os.path.join(tmp_dir, coast_mask))
        s3_client.download_file(coast_bucket, cells_lookup, os.path.join(tmp_dir, cells_lookup))

        # now do the geoprocessing to dowload the files one at a time into memory,
        # mask them by the coast buffer
        # and turn them into nice geoparquets
        for _, row in archive_urls.iterrows():
            era5_10_vectors_to_table(era5_wind_increment_path=row['archive_url'],
                                    era5_wind_parquet=row['parquet_path'],
                                    wind_vector_dim=row['era5_wind_dim'],
                                    coast_mask_path=coast_mask_path,
                                    cells_lookup_path=cells_lookup_path)

