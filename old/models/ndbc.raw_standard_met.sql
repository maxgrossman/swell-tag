MODEL(
    name ndbc_duck.raw_measurements,
    kind INCREMENTAL_BY_TIME_RANGE (
        time_column timestamp_tz,
    ),
    start '2000-01-01',
    columns (
        station_id varchar,
        timestamp_tz timestamptz,
        line varchar[]
    )
);

SET threads = 1;

SELECT station_id, timestamp_tz, line from (
    SELECT station_id, timestamp_tz, line
    FROM read_parquet('s3://swell-tags-us-east-1/bronze/raw/ndbc/**/*.parquet', hive_partitioning = true)
    WHERE timestamp_tz BETWEEN @start_dt AND  @end_dt
    ORDER BY station_id, timestamp_tz
    LIMIT 70000
);
