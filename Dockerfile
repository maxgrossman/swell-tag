FROM public.ecr.aws/lambda/python:3.12 as builder
RUN dnf install -y gcc postgresql-devel && \
    dnf clean all

# Copy requirements file
COPY pyproject.toml install_duckdb_requirements.py /opt
WORKDIR /opt
RUN curl -o global-bundle.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
RUN mkdir -p /opt/duckdb_extensions
RUN pip install --no-cache-dir -e . --target /opt/install
RUN PYTHONPATH=/opt/install python install_duckdb_requirements.py


FROM public.ecr.aws/lambda/python:3.12
RUN dnf install -y postgresql-devel expat && \
    dnf clean all
COPY --from=builder /opt/install ${LAMBDA_TASK_ROOT}/
COPY --from=builder /opt/duckdb_extensions ${LAMBDA_TASK_ROOT}/
COPY --from=builder /opt/global-bundle.pem ${LAMBDA_TASK_ROOT}/

COPY ./archive_builders ${LAMBDA_TASK_ROOT}/archive_builders
COPY ./bronze ${LAMBDA_TASK_ROOT}/bronze
COPY ./handlers ${LAMBDA_TASK_ROOT}/handlers
COPY ./models ${LAMBDA_TASK_ROOT}/models
COPY ./macros ${LAMBDA_TASK_ROOT}/macros
COPY ./audits ${LAMBDA_TASK_ROOT}/audits
COPY ./tests ${LAMBDA_TASK_ROOT}/tests
COPY ./config.yaml ${LAMBDA_TASK_ROOT}
