import json
import os

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

@enforce_model
@with_rds_credentials
def handler(event, context):
    with duckdb.connect() as conn:
        setup(conn)
        setup_ducklake_connection(conn)

        for model in event.models:
            for r in event.ranges:
                print(f'{model}: {r} {str(len(r))}')
                run_incremental_model(conn, model, r)

@as_step_function_step
def handler_ecs():
    # live dangerously, but mostly make sure we explode an error when we get one
    print("STARING ECS HANDLER")
    step_state = json.loads(os.getenv("STATE_DATA", "{}"))
    print("USING STATE -> " + json.dumps(step_state))
    return handler(step_state, {})

