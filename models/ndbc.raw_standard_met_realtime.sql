MODEL(
    name ndbc_duck.raw_measurements_realtime,
    kind INCREMENTAL_BY_TIME_RANGE (
        time_column timestamp_tz
    ),
    cron '@hourly',
    start '2026-07-01',
    columns (
        station_id varchar,
        timestamp_tz timestamptz,
        line varchar[]
    )
);

SET threads=4; SET force_download=true;

SET VARIABLE realtime_urls = (
    SELECT list(realtime_url) FROM (
        select realtime_url from read_csv('data/ndbc.realtime.csv') 
         where start_time <= @end_dt and 
               end_time >= @start_dt
    )
);

WITH parsed_lines AS 
    (SELECT str_split(filename,'realtime2/')[2][:5] AS station_id, 
            str_split(regexp_replace(column0,'\s+',',', 'g'),',') AS line
    FROM read_csv(getvariable('realtime_urls'),comment='#',header=false,skip=1)),
-- go get the max timestamp we have from the historical archive.
max_station_lines AS 
    (SELECT station_id, max(timestamp_tz) AS max_timestamp_tz
    FROM ndbc_duck.raw_measurements
    GROUP BY station_id),
table_lines AS 
    (SELECT station_id, 
            MAKE_TIMESTAMPTZ(
                line[1]::bigint,
                line[2]::bigint,
                line[3]::bigint,
                line[4]::bigint,
                line[5]::bigint,
                -- invalid guys in here in some files.
                case when line[5]::bigint >= 60 
                    then 0 
                    else line[5]::bigint end,
                0.0,
                'UTC'
            ) as timestamp_tz, 
            line
    FROM parsed_lines)
--  only keep lines from realtime that are newer than the last archived date since they can intersect.
SELECT table_lines.station_id, table_lines.timestamp_tz, table_lines.line
FROM max_station_lines
INNER JOIN table_lines
ON max_station_lines.station_id = table_lines.station_id
AND max_station_lines.max_timestamp_tz < table_lines.timestamp_tz
WHERE timestamp_tz BETWEEN @start_dt and  @end_dt
ORDER BY station_id, timestamp_tz asc
