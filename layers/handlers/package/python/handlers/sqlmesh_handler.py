import itertools
import subprocess
import constants
import sqlmesh

from datetime import datetime, timedelta, UTC
from sqlmesh.core.snapshot.definition import merge_intervals
from utils import split_year

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

def initialize_models(plan_command, select_models):
    # crap but i think because of the way we read in the csvs to a variable, something
    # w/sqlmesh or the sqlglot ignores the 'set' statement the first time you run the plan
    # might be a bs theory but basing on howi see that when i render the model on a fresh go,
    # the 'set variable' is no where to be found!
    # for right now right now, calling plan twice gets around it...
    # in spirit of actually doing my job, first idea was to load the csvs via env var.
    # that feels sidecard-y but not like you loose the direct rel between 'i need the archive table to exist'
    # which is the requirement for these tables.
    for model_arg in zip(select_models,select_models[1:]):
        for _ in range(2):
            try:
                run_shell_cmd(plan_command + model_arg + ['--skip-backfill', '--auto-apply'])
            except Exception:
                pass

sqlmesh_command = ['sqlmesh', '--log-to-stdout']

def handler_select_full(event, context):
    select_models = models_to_args(event.get('models'))
    plan_command = sqlmesh_command + ['--gateway', event.get('gateway', 'duckdb_local'), 'plan']
    plan_command = plan_command + select_models + ['--auto-apply']
    run_shell_cmd(plan_command)

def handler_initialize_models(event, context):
    select_models = models_to_args(event.get('models'))
    plan_command = sqlmesh_command + ['--gateway', event.get('gateway', 'duckdb_local'), 'plan']
    initialize_models(plan_command, select_models)

def handler_select_interval(event, context):
    select_models = models_to_args(event.get('models'))
    start_end_args = [start_end_to_args(select_range[0], select_range[1]) for select_range in event.get('ranges')]
    plan_command = sqlmesh_command + ['--gateway', event.get('gateway', 'duckdb_local'), 'plan']
    initialize_models(plan_command, select_models)

    # since duckdb doesn't spill for every op + only 10 gbs of storage n lambda, 
    # go ranges at a time
    for start_end_arg in start_end_args:
        run_shell_cmd(plan_command + ['dev'] + select_models + start_end_arg + ['--auto-apply'])
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

def handler_build_missing_intervals(event, context):
    context = sqlmesh.Context(paths='.')
    all_intervals = []
    for model in constants.RAW_MODELS:
        check = context.check_intervals(
            environment=event.get('environment', 'prod'),
            no_signals=False,
            select_models=[model]
        )
     
        intervals = check[list(check.keys())[0]].intervals
        merged_intervals = merge_intervals(intervals)
        all_intervals += merged_intervals

    all_merged_isos = [
        [datetime.fromtimestamp(epoch/1000,UTC) for epoch in interval] \
        for interval in merge_intervals(all_intervals)
    ]

    final_intervals = []
    for interval in all_merged_isos:
        final_intervals = final_intervals + split_year(interval,[])

    return {'missing_intervals':final_intervals}
