import json
import os
import boto3
from bronze.constants import EVENT_TO_BRONZE_MAP
from archive_builders.common import setup
from archive_builders.common import lambda_duck as duckdb

S3_BUCKET = os.getenv('SWELL_TAGS_BUCKET', 's3://swell-tags')

s3_client = boto3.client('s3')

def handler(event, context):
    partitions_manifest = event.get('partition_manifest')
    if not partitions_manifest:
        return {}

    bronze_function = EVENT_TO_BRONZE_MAP.get(event.get('archive'))
    if not bronze_function:
        raise KeyError('You gave me an archive I do not know about.')

    # Retrieve the object
    print("DOWNLOADING PARTITIONS FILE")
    response = s3_client.get_object(Bucket=partitions_manifest['Bucket'], Key=partitions_manifest['Key'])
    partitions = response['Body'].read().decode('utf-8').split('\n')

    print(f"HAVE {len(partitions)} TO ARCHIVE!")

    with duckdb.connect() as conn:
        conn = duckdb.connect()
        setup(conn)
        bronze_function(conn, S3_BUCKET, partitions)
        return {'archive': event.get('archive')}

def handler_ecs():
    # live dangerously, but mostly make sure we explode an error when we get one
    print("STARING ECS HANDLER")
    step_state = json.loads(os.getenv("STATE_DATA", "{}"))
    print("USING STATE -> " + json.dumps(step_state))
    return handler(step_state, {})
