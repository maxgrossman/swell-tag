import json
import os
from handlers.utils import run_full_model, with_rds_credentials, as_step_function_step, setup_ducklake_connection
from archive_builders.common import lambda_duck as duckdb
from archive_builders.common import setup


@with_rds_credentials
def handler(event, context):
    with duckdb.connect() as conn:
        setup(conn)
        setup_ducklake_connection(conn)
        for model in event.get('baselines'):
            run_full_model(conn, model)
    return event

@as_step_function_step
def handler_ecs():
    # live dangerously, but mostly make sure we explode an error when we get one
    print("STARING ECS HANDLER")
    step_state = json.loads(os.getenv("STATE_DATA", "{}"))
    print("USING STATE -> " + json.dumps(step_state))
    return handler(step_state, {})

