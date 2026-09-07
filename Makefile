start_year := 2000
end_year := 2026
aws_account := 691598168893
tag := 0.0.1
east_ecr := $(aws_account).dkr.ecr.us-east-1.amazonaws.com
west_ecr := $(aws_account).dkr.ecr.us-west-2.amazonaws.com
east_tag := $(east_ecr)/swell-tags:$(tag)
west_tag := $(west_ecr)/swell-tags:$(tag)

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
ecr_login:
	aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(east_ecr)
	aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $(west_ecr)
ecr_push:
	aws ecr batch-delete-image --region us-east-1 --repository-name swell-tags --image-ids imageTag=$(tag)
	aws ecr batch-delete-image --region us-west-2 --repository-name swell-tags --image-ids imageTag=$(tag)
	docker build --platform linux/amd64 --provenance=false -t $(east_tag) .
	docker tag $(east_tag) $(west_tag)
	docker push $(east_tag)
	docker push $(west_tag)



coop_index: data/coop.archive.csv


.PHONY: data_index backfill