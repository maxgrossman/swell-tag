import json
import os
from handlers.constants import SQLMESH_COMMAND, SQLMESH_GATEWAY
from handlers.utils import models_to_args, run_shell_cmd, load_db_credentials

def handler(event, context):
    if os.getenv("RDSSECRETARN") is None:
        raise Exception("Missing RDSSECRETARN")

    load_db_credentials(
        region_name=os.getenv("AWS_REGION"),
        secret_name=os.getenv("RDSSECRETARN")
    )
    select_models = models_to_args(event.get('models'))
    plan_command = SQLMESH_COMMAND + ['--gateway', SQLMESH_GATEWAY, 'plan']
    plan_command = plan_command + select_models + ['--auto-apply']
    run_shell_cmd(plan_command)

def handler_ecs():
    # live dangerously, but mostly make sure we explode an error when we get one
    print("STARING ECS HANDLER")
    step_state = json.loads(os.getenv("STATE_DATA", "{}"))
    print("USING STATE -> " + json.dumps(step_state))
    return handler(step_state, {})

