from handlers.utils import models_to_args, start_end_to_args, initialize_models
from handlers.constants import SQLMESH_COMMAND, SQLMESH_GATEWAY
from handlers.models import EventModel, enforce_model
from handlers.boto_helpers import load_rds_credentials

@enforce_model
@load_rds_credentials
def handler(event, context):
    select_models = models_to_args(event.get('models'))
    start_end_args = [start_end_to_args(select_range[0], select_range[1]) for select_range in event.get('ranges')]
    plan_command = SQLMESH_COMMAND + ['--gateway', SQLMESH_GATEWAY, 'plan']
    initialize_models(plan_command, select_models)