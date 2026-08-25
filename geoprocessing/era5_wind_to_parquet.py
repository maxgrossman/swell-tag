import duckdb
import rioxarray
import xarray as xr
import geopandas as gpd
import json
import tempfile
import argparse
import numpy as np
from pathlib import Path
from shapely.geometry import mapping

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
    coast_mask_path: str,
    cells_lookup_path: str,
):
    with tempfile.TemporaryDirectory() as temp_zarr_dir, \
         open(cells_lookup_path,'r') as cell_lookup, \
         open(coast_mask_path, 'r') as cell_mask:

        cells_lookup = json.loads(cell_lookup.read())['cells']
        mask_gdf = gpd.read_file(cell_mask)
        temp_zarr = Path(temp_zarr_dir, 'tmp.zarr').as_posix()

        print('CLIPPING ERA5 TO COAST BOUNDS')
        # rio to make xarray mask from buffer. "clip" the era5 wind to that boundary
        ds = apply_lon_lat_conventions(xr.open_dataset(era5_wind_increment_path))
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

def main():
    app = argparse.ArgumentParser(prog='era5_wind_to_parquet')
    app.add_argument('--era5_wind_netcdf', required=True)
    app.add_argument('--era5_wind_parquet', required=True)
    app.add_argument('--era5_wind_dim', required=True)
    app.add_argument('--coast_mask', required=True)
    app.add_argument('--cells_lookup', required=True)

    args = app.parse_args()

    era5_10_vectors_to_table(era5_wind_increment_path=args.era5_wind_netcdf,
                             era5_wind_parquet=args.era5_wind_parquet,
                             wind_vector_dim=args.era5_wind_dim,
                             coast_mask_path=args.coast_mask,
                             cells_lookup_path=args.cells_lookup)

if __name__ == '__main__':
    main()