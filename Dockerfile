FROM public.ecr.aws/lambda/python:3.12 as builder
# Copy requirements file
COPY requirements.txt /opt

# Install dependencies
RUN python -m venv /opt/venv && /opt/venv/bin/pip install -r /opt/requirements.txt

FROM public.ecr.aws/lambda/python:3.12
COPY --from=builder /opt/venv/lib/python3.12/site-packages/ ${LAMBDA_TASK_ROOT}/
COPY geoprocessing/era5_wind_to_parquet.py ${LAMBDA_TASK_ROOT}/
COPY lambda_handlers/*.py ${LAMBDA_TASK_ROOT}/

