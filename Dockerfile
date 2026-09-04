FROM public.ecr.aws/lambda/python:3.12 as builder
# Copy requirements file
COPY pyproject.toml /opt
WORKDIR /opt

# Install dependencies
RUN pip install --no-cache-dir -e . --target /opt/install

FROM public.ecr.aws/lambda/python:3.12
COPY --from=builder /opt/install ${LAMBDA_TASK_ROOT}/
COPY ./handlers ${LAMBDA_TASK_ROOT}/handlers
COPY ./models ${LAMBDA_TASK_ROOT}/models
COPY ./macros ${LAMBDA_TASK_ROOT}/macros
COPY ./audits ${LAMBDA_TASK_ROOT}/audits
COPY ./tests ${LAMBDA_TASK_ROOT}/tests
COPY ./config.yaml ${LAMBDA_TASK_ROOT}
