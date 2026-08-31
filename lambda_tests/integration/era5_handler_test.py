import pytest
import os

from layers.handlers.era5_handler import get_new_archives_handler, era5_netcdf_to_geoparquet_handler

def test_get_new_era5_handlers():
    os.environ['SWELL_TAGS_DB'] = 'data/swell_tags.db'
    event_results = get_new_archives_handler(event={}, context={})
    assert 3 == len(event_results['era5_to_backfill'][0])

def test_era5_netcdf_to_geoparquet_handler():
    os.environ['SWELL_TAGS_DB'] = 'data/swell_tags.db'
    era5_netcdf_to_geoparquet_handler(
        event={
            'era5_to_backfill': [[
                's3://nsf-ncar-era5/e5.oper.an.sfc/200001/e5.oper.an.sfc.128_165_10u.ll025sc.2000010100_2000013123.nc', 
                'e5.oper.an.sfc.128_165_10u.ll025sc.2000010100_2000013123.parquet', 
                'VAR_10U'
            ]]
        }, 
        context={}
    )
