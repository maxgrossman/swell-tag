import itertools
import subprocess
import sqlmesh

def run_shell_cmd(command, run_kwargs={'check':True}):
    print(' '.join(command))
    subprocess.run(command, **run_kwargs) 

def models_to_args(select_models):
    if not select_models:
        raise Exception('Must provide select models for select handler')

    return list(itertools.chain(*list(map(lambda model: ['--select-model', model], select_models))))

def start_end_to_args(start, end):
    if not start and not end:
        raise Exception('Must provide start and end interval')

    return ['--start', start, '--end', end]


sqlmesh_command = ['sqlmesh', '--log-to-stdout']

def handler_select_full(event, context):
    select_models = models_to_args(event.get('models'))
    plan_command = sqlmesh_command + ['--gateway', event.get('gateway', 'duckdb_local'), 'plan']
    plan_command = plan_command + select_models + ['--auto-apply']
    run_shell_cmd(plan_command)

def handler_select_interval(event, context):
    select_models = models_to_args(event.get('models'))
    start_end_args = start_end_to_args(event.get('start'), event.get('end'))

    # crap but i think because of the way we read in the csvs to a variable, something
    # w/sqlmesh or the sqlglot ignores the 'set' statement the first time you run the plan
    # might be a bs theory but basing on howi see that when i render the model on a fresh go,
    # the 'set variable' is no where to be found!
    # for right now right now, calling plan twice gets around it...
    # in spirit of actually doing my job, first idea was to load the csvs via env var.
    # that feels sidecard-y but not like you loose the direct rel between 'i need the archive table to exist'
    # which is the requirement for these tables.
    plan_command = sqlmesh_command + ['--gateway', event.get('gateway', 'duckdb_local'), 'plan']
    run_shell_cmd(plan_command + select_models + ['--skip-backfill', '--auto-apply'], run_kwargs={
        'capture_output':True, 
        'text':True
    })
    run_shell_cmd(plan_command + select_models + ['--skip-backfill', '--auto-apply'])
    # go grab that data
    run_shell_cmd(plan_command + ['dev'] + select_models + start_end_args + ['--auto-apply'])
    # then copy it up to the prod tables
    run_shell_cmd(plan_command + select_models + ['--skip-backfill', '--auto-apply'])

def handler_ensure_dependencies(event, context):
    models = event.get('models')
    table_name_command = sqlmesh_command + ['--gateway', event.get('gateway', 'duckdb_local'), 'table_name']

    for model in models:
        try:
            run_shell_cmd(table_name_command + [model])
        except Exception:
            return {'status': 'missing_dependencies'}

    return {'status': 'have_dependencies'}