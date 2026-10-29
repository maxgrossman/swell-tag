import urllib.parse
import os
import json
import boto3
from botocore.exceptions import ClientError
import itertools
import subprocess
from datetime import timedelta, datetime
from calendar import isleap
from functools import wraps
from handlers.constants import MODEL_TO_PATH, PARQUET_PATH_REPLACE

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
    for select_model in select_models:
        for _ in range(2):
            try:
                run_shell_cmd(plan_command + ['--select-model', select_model] + ['--skip-backfill', '--auto-apply'])
            except Exception as e:
                # print(e)
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

def with_rds_credentials(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        region_name=os.getenv("AWS_REGION")
        secret_name=os.getenv("RDSSECRETARN")
        if secret_name is None:
            raise Exception("Missing RDSSECRETARN")
        load_db_credentials(region_name,secret_name)
        return func(*args, **kwargs)
    return wrapper


def as_step_function_step(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        print('starting passing data to task token')
        task_token = os.environ.get("TASK_TOKEN")
        if not task_token:
            print("Error: TASK_TOKEN environment variable not found.")
            return

        sfn_client = boto3.client('stepfunctions')
        try:
            result = func(*args, **kwargs)
            print('passing state to task token -> ' + json.dumps(result))
            sfn_client.send_task_success(
                taskToken=task_token,
                output=json.dumps(result)
            )
            return result
        except Exception as e:
            sfn_client.send_task_failure(
                taskToken=task_token,
                error="ContainerExecutionError",
                cause=str(e)
            )
            return None

    return wrapper

def get_model_sql(model):
    model_path = MODEL_TO_PATH.get(model)

    if not model_path:
        raise Exception(f'unknown model -> ' + model + '; i know -> ' + ','.join(MODEL_TO_PATH.keys()))

    with open(model_path, 'r') as model_handler:
        return model_handler.read()

def run_full_model(conn, model):
    conn.execute(get_model_sql(model))

def run_incremental_model(conn, model, r):
    start_dt = r[0]
    end_dt = r[1]
    model_str = get_model_sql(model)
    if model in PARQUET_PATH_REPLACE and len(r) == 3:
        model_str = model_str.replace('$parquet_path', urllib.parse.quote(r[2]))

    conn.execute(model_str, {'start_dt': start_dt, 'end_dt': end_dt})

def setup_ducklake_connection(conn):
    conn.load_extension('postgres')
    conn.load_extension('ducklake')
    conn.execute(
        """
        CREATE SECRET postgres_metadata (
            TYPE postgres,
            HOST $PGHOST,
            PORT $PGPORT,
            DATABASE $PGDATABASE,
            USER $PGUSER,
            PASSWORD $PGPASSWORD
        );
        """,
        {
            "PGHOST": os.getenv("PGHOST"),
            "PGPORT": os.getenv("PGPORT"),
            "PGDATABASE": os.getenv("PGDATABASE"),
            "PGUSER": os.getenv("PGUSER"),
            "PGPASSWORD": os.getenv("PGPASSWORD")
        }
    );
    conn.execute(
        """
        CREATE SECRET swell_tags (
            TYPE ducklake,
            METADATA_PATH '',
            METADATA_SCHEMA 'swell_tags_metadata',
            DATA_PATH $DUCKLAKE_DATAPATH,
            METADATA_PARAMETERS MAP {
                'TYPE': 'postgres',
                'SECRET': 'postgres_metadata'
            }
        );
        """,
        {
            'DUCKLAKE_DATAPATH': os.getenv("DUCKLAKE_DATAPATH")
        }
    )
    conn.execute( "ATTACH '' as metadata (type postgres, schema 'swell_tags_metadata', secret 'postgres_metadata');")
    conn.execute(
        "ATTACH 'ducklake:swell_tags' AS swell_tags (DATA_INLINING_ROW_LIMIT $DATA_INLINING_ROW_LIMIT, OVERRIDE_DATA_PATH true)",
        {
            "DATA_INLINING_ROW_LIMIT": os.getenv("DATA_INLINING_ROW_LIMIT", 1000)
        }
    )
    conn.execute("USE swell_tags;")

    return conn;

