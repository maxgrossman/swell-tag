from handlers.constants import SQLMESH_COMMAND, SQLMESH_GATEWAY
from handlers.utils import models_to_args, run_shell_cmd 

def handler(event, context):
    select_models = models_to_args(event.get('models'))
    plan_command = SQLMESH_COMMAND + ['--gateway', SQLMESH_GATEWAY, 'plan']
    plan_command = plan_command + select_models + ['--auto-apply']
    run_shell_cmd(plan_command)