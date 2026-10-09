create schema if not exists ndbc;
create table if not exists ndbc.standard_measurements (
    station_id varchar,
    timestamp_tz timestamptz,
    station_sk int,
    geometry geometry,
    h3_04 uint64,
    wind_direction int,
    wind_speed double,
    wind_gust double,
    wave_height double,
    dominant_wave_period double,
    average_wave_period double,
    measured_wave_direction int,
    sea_level_pressure double,
    air_temp double,
    water_temp double,
    dew_point_temp double,
    visibility double,
    tide double
);

LOAD spatial;
LOAD h3;

WITH
raw_history AS (
    SELECT raw_meas.station_id,
            raw_meas.timestamp_tz,
            raw_meas.line
    FROM (
        SELECT station_id::varchar as station_id, timestamp_tz, line
        FROM read_parquet('s3://swell-tags-us-east-1/bronze/raw/ndbc/**/*.parquet', hive_partitioning = true)
        WHERE timestamp_tz BETWEEN $start_dt and $end_dt
    ) as raw_meas
    LEFT JOIN ndbc.standard_measurements
    ON ndbc.standard_measurements.station_id = raw_meas.station_id AND
        ndbc.standard_measurements.timestamp_tz = raw_meas.timestamp_tz
    WHERE ndbc.standard_measurements.station_id IS NULL
    AND raw_meas.timestamp_tz  BETWEEN $start_dt AND $end_dt
),
-- raw_realtime AS
--     (SELECT raw_meas_rt.station_id,
--             raw_meas_rt.timestamp_tz,
--             raw_meas_rt.line
--     FROM (
--         SELECT station_id, timestamp_tz, line
--         FROM read_parquet('s3://swell-tags-us-east-1/bronze/raw/ndbc_realtime/**/*.parquet', hive_partitioning = true)
--         WHERE timestamp_tz BETWEEN $start_dt and $end_dt
--     ) as raw_meas_rt
--     LEFT JOIN ndbc.standard_measurements
--     ON ndbc.standard_measurements.station_id = raw_meas_rt.station_id AND
--         ndbc.standard_measurements.timestamp_tz = raw_meas_rt.timestamp_tz
--     WHERE ndbc.standard_measurements.station_id IS NULL
--     AND raw_meas_rt.timestamp_tz BETWEEN $start_dt AND $end_dt),
--     ,
-- raw_latest_obs AS
--     (SELECT raw_meas_latest.station_id,
--             raw_meas_latest.timestamp_tz,
--             raw_meas_latest.line[4:]
--     FROM (
--         SELECT station_id, timestamp_tz, line
--         FROM read_parquet('s3://swell-tags-us-east-1/bronze/raw/ndbc_latest/**/*.parquet', hive_partitioning = true)
--         WHERE timestamp_tz BETWEEN $start_dt and $end_dt
--     ) as raw_meas_latest
--     LEFT JOIN ndbc.standard_measurements
--     ON ndbc.standard_measurements.station_id = raw_meas_latest.station_id AND
--         ndbc.standard_measurements.timestamp_tz = raw_meas_latest.timestamp_tz
--     WHERE ndbc.standard_measurements.station_id IS NULL
--     AND raw_meas_latest.timestamp_tz BETWEEN $start_dt AND $end_dt),
all_raw_obs AS
    (SELECT station_id, timestamp_tz, line from raw_history
    --  UNION ALL
    --  SELECT station_id, timestamp_tz, line from raw_realtime
    --  UNION ALL
    --  SELECT station_id, timestamp_tz, line from raw_realtime
     ),
new_raw_obs as
    (SELECT DISTINCT ON (station_id, timestamp_tz)
        all_raw_obs.station_id,
        timestamp_tz, line,
        bouy_history.station_sk,
        bouy_history.geometry,
        bouy_history.h3_04
    FROM all_raw_obs
    JOIN ndbc.bouy_history
    ON timestamp_tz <= coalesce(ndbc.bouy_history.end_time, timestamp_tz)
    AND all_raw_obs.station_id = ndbc.bouy_history.station_id
    ORDER BY station_id, timestamp_tz ASC)
--CREATE FINAL, TRANSFORMED/QUERIABLE VIEW OF THE RAW DATA.
INSERT INTO ndbc.standard_measurements
SELECT
    new_raw_obs.station_id::varchar,
    new_raw_obs.timestamp_tz,
    new_raw_obs.station_sk,
    new_raw_obs.geometry,
    new_raw_obs.h3_04,
    coalesce(try_cast(new_raw_obs.line[6] as int), 999)::int as wind_direction,
    coalesce(try_cast(new_raw_obs.line[7] as double),999.9)::double as wind_speed,
    coalesce(try_cast(new_raw_obs.line[8] as double),999.9)::double as wind_gust,
    coalesce(try_cast(new_raw_obs.line[9] as double),999.9)::double as wave_height,
    coalesce(try_cast(new_raw_obs.line[10] as double),999.9)::double as dominant_wave_period,
    coalesce(try_cast(new_raw_obs.line[11] as double),999.9)::double average_wave_period,
    coalesce(try_cast(new_raw_obs.line[12] as double),999.9)::double as measured_wave_direction,
    coalesce(try_cast(new_raw_obs.line[13] as double),999.9)::double as sea_level_pressure,
    coalesce(try_cast(new_raw_obs.line[14] as double),999.9)::double as air_temp,
    coalesce(try_cast(new_raw_obs.line[15] as double),999.9)::double as water_temp,
    coalesce(try_cast(new_raw_obs.line[16] as double),999.9)::double as dew_point_temp,
    coalesce(try_cast(new_raw_obs.line[17] as double),999.9)::double as visibility,
    coalesce(try_cast(new_raw_obs.line[18] as double),999.9)::double as tide
FROM new_raw_obs
-- only the new new!
ANTI JOIN ndbc.standard_measurements t_standard_meas
ON t_standard_meas.station_id = new_raw_obs.station_id AND
   t_standard_meas.timestamp_tz = t_standard_meas.timestamp_tz
WHERE timestamp_tz BETWEEN $start_dt AND $end_dt

