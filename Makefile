start_year := 2000
end_year := 2026

venv: 
	python -m venv venv && venv/bin/python -m pip install -r requirements.txt
data/era5.10uv.archive.csv:
	venv/bin/python -m index_builders.build_era5_wind_archive
data/coast_buffer_h3.geojson:
	duckdb < geo_builders/coast_buffer_h3.sql
data/coast_buffer.geojson:
	duckdb < geo_builders/coast_buffer.sql
data/coast_lookup.json:
	duckdb < geo_builders/coast_lookup.sql
data/ndbc.archive.csv:
	duckdb < index_builders/build_ndbc_archive.sql
data/ndbc.realtime.csv:
	duckdb < index_builders/build_ndbc_realtime.sql
data/isd.archive.parquet: venv
	venv/bin/python -m index_builders.build_isd_archive
data/ushlc.archive.csv:
	duckdb < index_builders/build_ushlc_archive.sql
data/coops.act.geojson:
	venv/bin/esri2geojson https://mapservices.weather.noaa.gov/static/rest/services/NOS_Observations/CO_OPS_Stations/FeatureServer/0 data/coops.act.geojson
data/coops.hist.geojson:
	venv/bin/esri2geojson https://mapservices.weather.noaa.gov/static/rest/services/NOS_Observations/CO_OPS_Stations/FeatureServer/3 data/coops.hist.geojson
data/coops.archive.csv: data/coops.hist.geojson data/coops.act.geojson
	duckdb < index_builders/build_coops_archive.sql
backfill: venv
	venv/bin/python -m backfill --start_year=$(start_year) --end_year=$(end_year)

coop_index: data/coop.archive.csv
bouy_index: data/ndbc.archive.csv data/ndbc.realtime.csv 
weather_index: data/isd.archive.parquet
tidal_guage_index: data/ushlc.archive.csv
data_index: bouy_index weather_index

.PHONY: data_index backfill