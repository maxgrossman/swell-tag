from handlers.constants import SQLMESH_COMMAND, SQLMESH_GATEWAY
from handlers.utils import run_shell_cmd
from handlers.models import EventModel, enforce_model

@enforce_model
def handler(event: EventModel, context):
    table_name_command = SQLMESH_COMMAND + ['--gateway', SQLMESH_GATEWAY, 'table_name']

    for model in event.models:
        try:
            run_shell_cmd(table_name_command + [model])
        except Exception as e:
            print(e)
            return {'status': 'missing_dependencies'}

    return {'status': 'have_dependencies'}