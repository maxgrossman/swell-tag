import boto3

from urllib.parse import urlparse

IDEMP_QUERY = f"""
current_parquets as (
    SELECT
        -- gets the archive time and wind component we can use to join and then ignore.
        url_decode(string_split(string_split(file,'/')[7],'=')[2])::timestamp as archive_time,
        lower(string_split(string_split(string_split(file,'/')[8],'=')[2], 'VAR_')[2]) as var
    FROM glob($raw_archive)
),
partitioned as (
    select archive_url from (select * from read_csv($source_archive)) as era5_archive
    left join current_parquets
    on era5_archive.start_timestamp_tz=current_parquets.archive_time and
       regexp_matches(era5_archive.archive_url, current_parquets.var)
    where current_parquets.var is NULL
)
"""


    # select archive_url, ntile($num_tiles) over (order by $order_key) as part
PARTITION_QUERY = """
partitioned as (
    select archive_url
    from read_csv($source_archive)
)
"""

def check_folder_exists(client, bucket_name, prefix):
    response = client.list_objects_v2(Bucket=bucket_name, Prefix=prefix, MaxKeys=1)
    return 'Contents' in response

def build_parititon_query(s3_bucket, num_tiles, archive):
    s3_bucket_name = urlparse(s3_bucket).netloc
    source_archive = s3_bucket + f'/bronze/{archive}_archive.csv'
    raw_archive = s3_bucket + f'/bronze/raw/{archive}/**/*.parquet'
    query_args = {'num_tiles': num_tiles,'source_archive': source_archive}
    partition_query = ""

    if check_folder_exists(boto3.client('s3'), s3_bucket_name, f'bronze/raw/{archive}/'):
        query_args['raw_archive'] = raw_archive
        partition_query += IDEMP_QUERY
    else:
        partition_query += PARTITION_QUERY

    final_query = f"""
    with
    {partition_query}
    select array_agg(archive_url) as partition_urls
    from (select archive_url, floor(random() * $num_tiles)::INTEGER as partition
          from partitioned)
    group by partition
    """

    return final_query, query_args
