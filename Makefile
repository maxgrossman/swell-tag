start_year := 2000
end_year := 2026
aws_account := 691598168893
tag := 0.0.1
east_ecr := $(aws_account).dkr.ecr.us-east-1.amazonaws.com
west_ecr := $(aws_account).dkr.ecr.us-west-2.amazonaws.com
east_tag := $(east_ecr)/swell-tags:$(tag)
west_tag := $(west_ecr)/swell-tags:$(tag)

ifneq (,$(wildcard .env))
    include .env
    export
endif

venv:
	python -m venv venv && venv/bin/python -m pip install -r requirements.txt
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
plan:
	tofu plan
apply:
	tofu apply
auto_apply:
	tofu apply -auto-approve

.PHONY: apply auto_apply