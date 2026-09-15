import os
import json
import boto3
from botocore.exceptions import ClientError
import itertools
import subprocess
from datetime import timedelta
from calendar import isleap

def year_days(year):
    return 365 + (1 if isleap(year) else 0)

def split_year(interval, intervals):
    interval_end = interval[0] + timedelta(days=year_days(interval[0].year))
    if interval_end < interval[1]:
        intervals.append([interval[0],interval_end - timedelta(microseconds=1)])
        return split_year([interval_end, interval[1]], intervals)

    intervals.append(interval)
    return intervals

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

def load_db_credentials(region_name, secret_name):
    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        # For a list of exceptions thrown, see
        # https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html
        raise e

    data = json.loads(get_secret_value_response['SecretString'])
    os.environ['PGPASSWORD'] = data['password']
