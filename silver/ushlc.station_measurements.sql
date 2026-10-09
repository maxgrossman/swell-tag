LOAD aws;
LOAD httpfs;
LOAD spatial;
LOAD webbed;
LOAD h3;

create schema if not exists ushlc;
create table if not exists ushlc.station_measurements (
    station_id varchar,
    timestamp_tz timestamptz,
    reading_mm int64,
    geometry geometry,
    h3_04 uint64
);

WITH
hrly as (
    select station_id, timestamp_tz, reading_mm
    from read_parquet('s3://swell-tags-us-east-1/bronze/raw/ushlc/**/*.parquet', hive_partitioning = true)
    WHERE timestamp_tz BETWEEN $start_dt and $end_dt
),
hrly_and_stations as (
    select
        hrly.station_id,
        hrly.timestamp_tz,
        hrly.reading_mm,
        ushlc.stations.geometry as geometry,
        ushlc.stations.h3_04
    from hrly
    join ushlc.stations on hrly.station_id = printf('%03d', ushlc.stations.uh_id) || ushlc.stations.version
)
INSERT INTO ushlc.station_measurements
SELECT * FROM hrly_and_stations
ANTI JOIN ushlc.station_measurements
ON hrly_and_stations.station_id = ushlc.station_measurements.station_id AND
   hrly_and_stations.timestamp_tz = ushlc.station_measurements.timestamp_tz