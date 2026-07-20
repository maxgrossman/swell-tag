venv: 
	python -m venv venv && venv/bin/python -m pip install -r requirements.txt
data/ndbc.locations.geojson:
	venv/bin/esri2geojson https://gis.ncdc.noaa.gov/arcgis/rest/services/ms/NDBCBuoys/MapServer/0 > data/ndbc.locations.geojson

