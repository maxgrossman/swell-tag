import os
import base64
import boto3
from datetime import datetime, UTC
from bronze.constants import EVENT_TO_PART_MAP
from archive_builders.common import setup
from archive_builders.common import lambda_duck as duckdb
from urllib.parse import urlparse


S3_BUCKET = os.getenv('SWELL_TAGS_BUCKET', 's3://swell-tags')
S3_BUCKET_NAME = urlparse(S3_BUCKET).netloc

def handler(event, context):
    archive = event.get('archive')
    partition_function = EVENT_TO_PART_MAP.get(archive)
    if not partition_function:
        raise KeyError('You gave me an archive I do not know about.')

    # seems like that'll play nice....
    num_tiles = event.get('num_tiles', 40) 
    
    with duckdb.connect() as conn:
        setup(conn)
        partitions = partition_function(conn, S3_BUCKET, num_tiles)
        partition_manifests = []
        s3_client = boto3.client('s3')
        right_now = datetime.now(UTC)
        today_iso = right_now.replace(hour=0,minute=0,second=0,microsecond=0).strftime('%Y-%m-%dT%H-%M-%S')

        for index, partition_urls in enumerate(list(partitions['partition_urls'].apply(lambda x: x.tolist()))):
            file_name =f"{today_iso}.part.{index}.txt"
            key = f'bronze/partitions/{archive}/' + file_name
            s3_client.put_object(
                Bucket = S3_BUCKET_NAME,
                Key = key,
                Body='\n'.join(partition_urls),
                ContentType='text/plain'
            )
            partition_manifests.append({
                'archive': archive,
                'partition_manifest': {'Bucket': S3_BUCKET_NAME, 'Key': key}
            })

        return partition_manifests
