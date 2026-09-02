start_year := 2000
end_year := 2026

venv: 
	python -m venv venv && venv/bin/python -m pip install -r requirements.txt
data/coops.act.geojson:
	venv/bin/esri2geojson https://mapservices.weather.noaa.gov/static/rest/services/NOS_Observations/CO_OPS_Stations/FeatureServer/0 data/coops.act.geojson
data/coops.hist.geojson:
	venv/bin/esri2geojson https://mapservices.weather.noaa.gov/static/rest/services/NOS_Observations/CO_OPS_Stations/FeatureServer/3 data/coops.hist.geojson
data/coops.archive.csv: data/coops.hist.geojson data/coops.act.geojson
	duckdb < index_builders/build_coops_archive.sql
backfill: venv
	venv/bin/python -m backfill --start_year=$(start_year) --end_year=$(end_year)

coop_index: data/coop.archive.csv

.PHONY: data_index backfill