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
           raw_meas.line,
           raw_meas.start_idx
    FROM (
        SELECT station_id::varchar as station_id, timestamp_tz, line,
               -- starting at 2005 all these guys started reporting the minute and very fun getting to start at that idx....
               case when string_split_regex(filename, '.txt')[1][-4:-1]::int < 2005 then 5 else 6 end as start_idx
        FROM read_parquet('s3://swell-tags-us-east-1/bronze/raw/ndbc/year=$parquet_path/**/*.parquet', hive_partitioning = true)
        WHERE timestamp_tz BETWEEN $start_dt and $end_dt
    ) as raw_meas
),
all_raw_obs AS (SELECT station_id, timestamp_tz, line, start_idx from raw_history),
new_raw_obs as (
    select
        all_raw_obs.station_id,
        timestamp_tz, line, start_idx,
        bouy_history.station_sk,
        bouy_history.geometry,
        bouy_history.h3_04,
    FROM all_raw_obs
    JOIN ndbc.bouy_history
     ON all_raw_obs.station_id = ndbc.bouy_history.station_id
    AND timestamp_tz between ndbc.bouy_history.start_time and coalesce(ndbc.bouy_history.end_time, timestamp_tz)
    ORDER BY station_id, timestamp_tz ASC)
--CREATE FINAL, TRANSFORMED/QUERIABLE VIEW OF THE RAW DATA.
INSERT INTO ndbc.standard_measurements
SELECT
    new_raw_obs.station_id::varchar,
    new_raw_obs.timestamp_tz,
    new_raw_obs.station_sk,
    new_raw_obs.geometry,
    new_raw_obs.h3_04,
    coalesce(try_cast(new_raw_obs.line[new_raw_obs.start_idx] as int), 999)::int as wind_direction,
    coalesce(try_cast(new_raw_obs.line[new_raw_obs.start_idx + 1] as double),999.9)::double as wind_speed,
    coalesce(try_cast(new_raw_obs.line[new_raw_obs.start_idx + 2] as double),999.9)::double as wind_gust,
    coalesce(try_cast(new_raw_obs.line[new_raw_obs.start_idx + 3] as double),99)::double as wave_height,
    coalesce(try_cast(new_raw_obs.line[new_raw_obs.start_idx + 4] as double),99)::double as dominant_wave_period,
    coalesce(try_cast(new_raw_obs.line[new_raw_obs.start_idx + 5] as double),99)::double average_wave_period,
    coalesce(try_cast(new_raw_obs.line[new_raw_obs.start_idx + 6] as double),999.9)::double as measured_wave_direction,
    coalesce(try_cast(new_raw_obs.line[new_raw_obs.start_idx + 7] as double),999.9)::double as sea_level_pressure,
    coalesce(try_cast(new_raw_obs.line[new_raw_obs.start_idx + 8] as double),999.9)::double as air_temp,
    coalesce(try_cast(new_raw_obs.line[new_raw_obs.start_idx + 9] as double),999.9)::double as water_temp,
    coalesce(try_cast(new_raw_obs.line[new_raw_obs.start_idx + 10] as double),999.9)::double as dew_point_temp,
    coalesce(try_cast(new_raw_obs.line[new_raw_obs.start_idx + 11] as double),999.9)::double as visibility,
    coalesce(try_cast(new_raw_obs.line[new_raw_obs.start_idx + 12] as double),99.0)::double as tide
FROM new_raw_obs
