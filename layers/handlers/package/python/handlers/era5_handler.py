import os
import tempfile
import duckdb
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

def era5_10_vectors_to_table(
    era5_wind_increment_path: str,
    era5_wind_parquet: str,
    wind_vector_dim: str,
    mask_gdf: gpd.GeoDataFrame,
    cells_lookup: pd.DataFrame,
):
    with tempfile.TemporaryDirectory() as temp_zarr_dir:
        temp_zarr = Path(temp_zarr_dir, 'tmp.zarr').as_posix()
        print('CLIPPING ERA5 TO COAST BOUNDS')
        ds = apply_lon_lat_conventions(xr.open_dataset(era5_wind_increment_path, engine="h5netcdf"))
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
        duckdb.sql(f"""
            INSTALL zarr from community; load zarr;
            INSTALL h3 from community; load h3; 
            # needa load the s3 secrets i bet.
            COPY (
                WITH 
                {wind_vector_dim} as (SELECT * FROM read_zarr('{temp_zarr}', dims=['time','coastal_points'])),
                time_table as (SELECT * FROM read_zarr('{temp_zarr}', dims=['time'])),
                longitude as (select * from read_zarr('{temp_zarr}', array_path='longitude')),
                latitude  as (select * from read_zarr('{temp_zarr}', array_path='latitude'))
                select {wind_vector_dim}, 
                        longitude, 
                        latitude, 
                        time_table.utc_date as utc_date, 
                        h3_latlng_to_cell(latitude,longitude,4) as h3_cell
                from {wind_vector_dim} 
                join longitude on {wind_vector_dim}.coastal_points = longitude.coastal_points
                join latitude on {wind_vector_dim}.coastal_points = latitude.coastal_points
                join time_table on {wind_vector_dim}.time = time_table.time
                order by h3_latlng_to_cell(latitude,longitude,4), time_table.utc_date
            )
            TO '{era5_wind_parquet}'
        """)

def get_new_archives_handler(event, context):
    # go find the archive urls that map to a month i do not yet have in swelltags.
    with duckdb.connect(os.getenv('SWELL_TAGS_DB')) as conn:
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

def era5_netcdf_to_geoparquet_handler(event, context):
    with duckdb.connect(os.getenv("SWELL_TAGS_DB")) as connection:
        coast_mask_df = connection.sql('select h3_04, ST_AsWKB(geom) as geom from coast.buffered_h3').df();
        coast_mask_df["geom"] = coast_mask_df["geom"].apply(bytes).apply(wkb.loads)
        coast_mask_gdf = gpd.GeoDataFrame(coast_mask_df, geometry="geom", crs="EPSG:4326")
        cells_lookup = connection.sql('select lats, lons from coast.cells_lookup').df()

        for archive_url, parquet_path, era5_wind_dim in event.get('era5_to_backfill', []):
            era5_10_vectors_to_table(
                era5_wind_increment_path=archive_url,
                era5_wind_parquet=parquet_path,
                wind_vector_dim=era5_wind_dim,                      
                mask_gdf=coast_mask_gdf,
                cells_lookup=cells_lookup
            )
