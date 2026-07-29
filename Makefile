start_year := 2000
end_year := 2026

venv: 
	python -m venv venv && venv/bin/python -m pip install -r requirements.txt
data/ndbc.archive.csv:
	duckdb < index_builders/build_ndbc_archive.sql
data/ndbc.realtime.csv:
	duckdb < index_builders/build_ndbc_realtime.sql
data/isd.archive.parquet: venv
	venv/bin/python -m index_builders.build_isd_archive
data/ushlc.archive.csv:
	duckdb < index_builders/build_ushlc_archive.sql
backfill: venv
	venv/bin/python -m backfill --start_year=$(start_year) --end_year=$(end_year)

bouy_index: data/ndbc.archive.csv data/ndbc.realtime.csv 
weather_index: data/isd.archive.parquet
tidal_guage_index: data/ushlc.archive.csv
data_index: bouy_index weather_index

.PHONY: data_index backfill