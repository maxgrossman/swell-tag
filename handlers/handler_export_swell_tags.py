import json
import os
import boto3

from datetime import datetime, timezone
from archive_builders.common import lambda_duck as duckdb
from archive_builders.common import setup

from handlers.utils import (
    # models_to_args, start_end_to_args, initialize_models,
    with_rds_credentials, as_step_function_step,
    # run_shell_cmd,
    run_incremental_model,
    setup_ducklake_connection
)
# from handlers.constants import SQLMESH_COMMAND, SQLMESH_GATEWAY
from handlers.models import EventModel, enforce_model

s3_client = boto3.client('s3')

@enforce_model
@with_rds_credentials
def handler(event, context):
    export_db = f'swell_tags.{datetime.now(timezone.utc).isoformat()}.db'
    export_db_2 = f'standard_measurements.{datetime.now(timezone.utc).isoformat()}.db'
    export_db_path = f'{os.getenv('HOME')}/{export_db}'
    export_db_2_path = f'{os.getenv('HOME')}/{export_db_2}'
    with duckdb.connect() as conn:
        setup(conn)
        setup_ducklake_connection(conn)
        conn.execute(f"ATTACH '{export_db_path}' AS export_db;")
        conn.execute('CREATE TABLE export_db.swell_tags as SELECT * FROM swell.tags;')
        conn.execute("DETACH export_db;")
        # conn.execute(f"ATTACH '{export_db_2_path}' AS export_db;")
        # conn.execute('CREATE TABLE export_db.ndbc_standard_measurements as SELECT * FROM ndbc.standard_measurements;')
        # conn.execute("DETACH export_db;")
    s3_client.upload_file(export_db_path, 'swell-tags-us-east-1', f'exports/{export_db}')
    # s3_client.upload_file(export_db_2_path, 'swell-tags-us-east-1', f'exports/{export_db_2}')


@as_step_function_step
def handler_ecs():
    # live dangerously, but mostly make sure we explode an error when we get one
    print("STARING ECS HANDLER")
    step_state = json.loads(os.getenv("STATE_DATA", "{}"))
    print("USING STATE -> " + json.dumps(step_state))
    return handler(step_state, {})

