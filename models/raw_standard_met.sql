MODEL(
    name ndbc_duck.raw_measurements,
    kind INCREMENTAL_BY_TIME_RANGE (
        time_column timestamp_tz
    ), 
    start '2000-01-01',
    columns (
        station_id varchar,
        timestamp_tz timestamptz,
        line varchar[]
    )
);

SET VARIABLE archive_urls = (
    SELECT list(archive_url) FROM (
        SELECT archive_url 
        FROM read_csv('data/ndbc.archive.csv')
        WHERE timestamp_tz BETWEEN @start_dt AND @end_dt
    )
);

-- so not to go too ham sammy on memory
SET threads=4;

WITH 
parsed_lines as 
    (SELECT str_split(filename,'stdmet/')[2][:5] as station_id, 
            str_split(regexp_replace(column0,'\s+',',', 'g'),',') as line
        FROM read_csv({station_archives_list}, comment='#', header=false, skip=1)),
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
            line
        FROM parsed_lines)
SELECT station_id, timestamp_tz, line
FROM table_lines
WHERE timestamp_tz BETWEEN @start_dt AND  @end_dt
ORDER BY station_id, timestamp_tz;
