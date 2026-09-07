import pandas as pd
from bronze.common import build_parititon_query

#if ever want before 2000 need to enjoy figuring parsing those older files...
ARCHIVE_QUERY = f"""
    SELECT archive_url, s3_url from read_csv($ndbc_archive)
    WHERE list_contains($partition, archive_url) and timestamp_tz > '1999-12-31T23:59:59Z'
"""

BRONZE_SQL_DOWNLOAD = f"""
COPY (
WITH 
parsed_lines as 
    (SELECT filename,
            str_split(filename,'stdmet/')[2][:5] as station_id, 
            str_split(regexp_replace(column0,'\\s+',',', 'g'),',') as line
        FROM read_csv($archive_urls, comment='#', header=false, skip=1)),
table_lines as 
    (SELECT station_id, 
            MAKE_TIMESTAMPTZ(
                line[1]::bigint,
                line[2]::bigint,
                line[3]::bigint,
                line[4]::bigint,
                -- invalid guys in here in some files.
                case when line[5]::bigint >= 60 
                        then 0 
                        else line[5]::bigint end,
                0.0::double,
                'UTC'
            ) as timestamp_tz, 
            date_trunc('year', timestamp_tz) as year,
            line,
            filename
        FROM parsed_lines)
SELECT filename, station_id, year, timestamp_tz, line
FROM table_lines
ORDER BY station_id, timestamp_tz
) TO $parquet_s3_path (FORMAT PARQUET, PARTITION_BY (year, station_id), APPEND true)
"""

def build_bronze_layer(conn, s3_bucket, partition):
    ndbc_archive = s3_bucket + '/bronze/ndbc_archive.csv'
    archive_info = conn.execute(ARCHIVE_QUERY, {'ndbc_archive': ndbc_archive, 'partition': partition}).df()
    archive_urls = list(archive_info['archive_url'])
    parquet_s3_path = s3_bucket + '/bronze/raw/ndbc/'
    conn.execute(BRONZE_SQL_DOWNLOAD, {
        'archive_urls': archive_urls,
        'parquet_s3_path': parquet_s3_path
    })

def build_bronze_partitions(conn, s3_bucket, num_tiles) -> pd.DataFrame:
    query, args = build_parititon_query(s3_bucket,num_tiles,'ndbc')
    return conn.execute(query, args).df()