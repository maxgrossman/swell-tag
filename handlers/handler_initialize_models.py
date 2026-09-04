from handlers.utils import models_to_args, initialize_models, start_end_to_args, run_shell_cmd
from handlers.constants import SQLMESH_COMMAND, SQLMESH_GATEWAY

def handler(event, context):
    select_models = models_to_args(event.get('models'))
    plan_command = SQLMESH_COMMAND + ['--gateway', SQLMESH_GATEWAY, 'plan']
    initialize_models(plan_command, select_models)

    select_models = models_to_args(event.get('models'))
    start_end_args = [start_end_to_args(select_range[0], select_range[1]) for select_range in event.get('ranges')]
    plan_command = SQLMESH_COMMAND + ['--gateway', SQLMESH_GATEWAY, 'plan']
    initialize_models(plan_command, select_models)

    # since duckdb doesn't spill for every op + only 10 gbs of storage n lambda, 
    # go ranges at a time
    for start_end_arg in start_end_args:
        run_shell_cmd(plan_command + ['dev'] + select_models + start_end_arg + ['--auto-apply'])
        # then copy it up to the prod tables
        run_shell_cmd(plan_command + select_models + ['--skip-backfill', '--auto-apply'])
