import boto3

from urllib.parse import urlparse

IDEMP_QUERY = f"""
current_parquets as (
    SELECT distinct filename as current_s3_url 
    FROM read_parquet($raw_archive) 
),
partitioned as (
    select archive_url, ntile($num_tiles) over (order by $order_key) as part 
    from read_csv($source_archive)
    left join current_parquets on current_s3_url = s3_url
    where current_s3_url is NULL
)
"""

PARTITION_QUERY = """
partitioned as (
    select archive_url, ntile($num_tiles) over (order by $order_key) as part 
    from read_csv($source_archive)
)
"""

def check_folder_exists(client, bucket_name, prefix):
    response = client.list_objects_v2(Bucket=bucket_name, Prefix=prefix, MaxKeys=1)
    return 'Contents' in response

def build_parititon_query(s3_bucket, num_tiles, archive, order_key):
    s3_bucket_name = urlparse(s3_bucket).netloc
    source_archive = s3_bucket + f'/bronze/{archive}_archive.csv'
    raw_archive = s3_bucket + f'/bronze/raw/{archive}/**/*.parquet'
    query_args = {'num_tiles': num_tiles,'source_archive': source_archive, 'order_key': order_key}

    partition_query = ""

    if check_folder_exists(boto3.client('s3'), s3_bucket_name, f'bronze/raw/{archive}/'):
        query_args['raw_archive'] = raw_archive
        partition_query += IDEMP_QUERY
    else:
        partition_query += PARTITION_QUERY

    final_query = f"""
    with
    {partition_query}
    select array_agg(archive_url) as partition_urls from partitioned group by part
    """

    return final_query, query_args
