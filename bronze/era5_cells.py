import os
import tempfile
import geopandas as gpd
import rioxarray
import xarray as xr
import pandas as pd
import geopandas as gpd
import numpy as np

from itertools import batched
from shapely import wkb
from shapely.geometry import mapping
from pathlib import Path

from bronze.common import build_parititon_query
from archive_builders.common import tmp_dir, lambda_duck

duckdb = lambda_duck

# so says lord gemini this is what we need 
# for requesting the open registry data in lambda
# 'not anonymously pay the transfer'
# https://confluence.ecmwf.int/plugins/viewsource/viewpagesrc.action?pageId=536218894
def apply_lon_lat_conventions(ds):
    # Flip latitudes (ensure they are monotonic increasing)
    if "latitude" in ds.dims:
        lats = ds["latitude"]
        if len(lats) > 1 and lats[0] > lats[-1]:
            ds = ds.reindex(latitude=ds.latitude[::-1])

    # Convert longitude to [-180, 180[
    if "longitude" in ds.dims and ds["longitude"].max() > 180:
        lons = ds["longitude"]
        lons_attrs = lons.attrs
        new_lons = np.concatenate([lons[lons >= 180], lons[lons < 180]])
        ds = ds.reindex(longitude=new_lons)
        ds = ds.assign_coords(longitude=(((ds["longitude"] + 180) % 360) - 180))
        ds["longitude"].attrs = lons_attrs

    return ds

def era5_netcdf_to_parquet(
    conn,
    era5_wind_increment_path: str,
    wind_vector_dim: str,
    parquet_s3_path: str,
    mask_gdf: gpd.GeoDataFrame,
    cells_lookup: pd.DataFrame,
):
    with tempfile.TemporaryDirectory(prefix=tmp_dir() +'/') as temp_zarr_dir:
        temp_zarr = Path(temp_zarr_dir, 'tmp.zarr').as_posix()
        print('CLIPPING ERA5 TO COAST BOUNDS')
        ds = apply_lon_lat_conventions(xr.open_dataset(
            era5_wind_increment_path, 
            engine="h5netcdf", 
        ))
        # rio to make xarray mask from buffer. "clip" the era5 wind to that boundary
        ds.rio.write_crs("EPSG:4326", inplace=True) 
        mask_gdf.set_crs(ds.rio.crs, inplace=True)
        # note the funky flip of the coordinates in the isel. can't say i know why that happened.
        clipped_ds = ds.rio.clip(mask_gdf.geometry.apply(mapping), mask_gdf.crs, drop=True).isel(latitude=slice(None, None, -1))
        # add dimension to the zarr that once read with duckdb can be used to write a bunch of rows
        # that give me a wind vector value for a specific h3 cell.
        print('CREATING DIM TO MATCH h3 CELLS')
        subset = clipped_ds.sel(
            latitude=xr.DataArray(cells_lookup['lats'], dims='coastal_points'), 
            longitude=xr.DataArray(cells_lookup['lons'], dims='coastal_points'), 
            method="nearest"
        )
        subset.to_zarr(temp_zarr)

        print('MAKE GEOPARQUET')
 
        # with the zarr made, use that duckdb power to write a geoparquet i can just load in to the database. 
        conn.execute("""
            COPY (
                WITH 
                $wind_vector_dim as (SELECT * FROM read_zarr($temp_zarr, dims=['time','coastal_points'])),
                time_table as (SELECT * FROM read_zarr($temp_zarr, dims=['time'])),
                longitude as (select * from read_zarr($temp_zarr, array_path='longitude')),
                latitude  as (select * from read_zarr($temp_zarr, array_path='latitude'))
                select $wind_vector_dim, 
                        longitude, 
                        latitude, 
                        time_table.utc_date as utc_date, 
                        date_trunc('month', time_table.utc_date) as utc_year,
                        h3_latlng_to_cell(latitude,longitude,4) as h3_cell
                from $wind_vector_dim 
                join longitude on $wind_vector_dim.coastal_points = longitude.coastal_points
                join latitude on $wind_vector_dim.coastal_points = latitude.coastal_points
                join time_table on $wind_vector_dim.time = time_table.time
                order by h3_latlng_to_cell(latitude,longitude,4), time_table.utc_date
            ) TO $parquet_s3_path (FORMAT PARQUET, PARTITION_BY (utc_month, $wind_vector_dim), APPEND true)
        """, {'wind_vector_dim': wind_vector_dim, 'temp_zarr': temp_zarr, 'parquet_s3_path': parquet_s3_path})

ARCHIVE_QUERY = f"""
    SELECT archive_url, s3_url from read_csv($era5_archive)
    WHERE list_contains($partition, archive_url)
"""

def build_bronze_layer(conn, s3_bucket, partition):
    era5_archive = s3_bucket + '/bronze/era5_archive.csv'
    cell_mask_uri = s3_bucket + '/bronze/coast_h3s.parquet'
    cell_lookup_uri = s3_bucket + '/bronze/coast_lookups.parquet'
    parquet_s3_path = s3_bucket + '/bronze/raw/era5/'

    mask_gdf = gpd.read_parquet(cell_mask_uri)
    cells_lookup = pd.read_parquet(cell_lookup_uri)

    archive_info = conn.execute(ARCHIVE_QUERY, {'era5_archive': era5_archive, 'partition': partition}).df()
    archive_urls = list(archive_info['archive_url'])

    conn.install_extension('zarr', repository='community')
    conn.load_extension('zarr')
    conn.install_extension('h3', repository='community')
    conn.load_extension('h3')

    os.environ['AWS_REQUEST_PAYER'] = 'requester'

    for archive_url in archive_urls:
        wind_vector_dim = 'VAR_10V' if '10v' in archive_url else 'VAR_10U'
        era5_netcdf_to_parquet(
            conn=conn, 
            era5_wind_increment_path=archive_url, 
            wind_vector_dim=wind_vector_dim, 
            parquet_s3_path=parquet_s3_path,
            mask_gdf=mask_gdf,
            cells_lookup=cells_lookup
        )

def build_bronze_partitions(conn, s3_bucket, num_tiles) -> pd.DataFrame:
    query, args = build_parititon_query(s3_bucket,num_tiles,'era5')
    return conn.execute(query, args).df()