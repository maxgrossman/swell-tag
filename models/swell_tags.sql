MODEL (
    name swell.tags,
    kind INCREMENTAL_BY_TIME_RANGE (
        time_column bouy_timestamp_tz
    ),
    start '2000-01-01'
);

INSTALL spatial;
LOAD spatial;
-- GET BOUY PART OF SWELL TAGS + THE TRUNC'D TIMESTMAP + QUADKEY TO PUSH DOWN TO USHLC ON...
WITH
ndbc_measurements_joinable AS (
    SELECT
        ndbc_duck.standard_measurements.station_id,
        ndbc_duck.standard_measurements.quadkey,
        ndbc_duck.standard_measurements.timestamp_tz,
        ndbc_duck.standard_measurements.wave_height,
        ndbc_duck.standard_measurements.dominant_wave_period,
        ndbc_duck.standard_measurements.average_wave_period,
        ndbc_duck.standard_measurements.measured_wave_direction,
        ndbc_duck.standard_measurements.tide,
        ndbc_duck.standard_measurements.quadkey,
        ST_GeomFROMWKB(ndbc_duck.standard_measurements.geometry) AS geometry,
        date_trunc ('hour', ndbc_duck.standard_measurements.timestamp_tz) AS hr
    FROM ndbc_duck.standard_measurements
    WHERE timestamp_tz BETWEEN @start_dt and @end_dt
),
-- JOIN TIDE TABLE ON QUADKEY+TRUNC'D TIME (TIDE MEASUREMENTS ARE HOURLY)
-- ON WHAT WE GET BACK, GET THAT TIDE MEASUREMENT + A RANKING ON THE CLOSEST BY SPACE AND TIME
ndbc_ushlc_joined AS (
    SELECT 
        hr,
        ndbc_measurements_joinable.timestamp_tz, 
        ndbc_measurements_joinable.station_id,
        ndbc_measurements_joinable.quadkey,
        ndbc_measurements_joinable.geometry,
        ndbc_measurements_joinable.timestamp_tz,
        ndbc_measurements_joinable.wave_height,
        ndbc_measurements_joinable.average_wave_period,
        ndbc_measurements_joinable.measured_wave_direction,
        ndbc_measurements_joinable.dominant_wave_period,
        ndbc_measurements_joinable.dominant_wave_period,
        ndbc_measurements_joinable.tide,
        ushlc.station_measurements.reading_mm, 
        ushlc.station_measurements.uh_id,
        ushlc.station_measurements.version,
        row_number() over (
            partition by ndbc_measurements_joinable.quadkey, ndbc_measurements_joinable.hr
            order by ST_Distance_Sphere(ndbc_measurements_joinable.geometry, ushlc.station_measurements.geometry) asc,
                        abs(epoch(ndbc_measurements_joinable.timestamp_tz)-epoch(ndbc_measurements_joinable.hr))) AS closeness
    FROM ndbc_measurements_joinable
    LEFT JOIN ushlc.station_measurements
    ON ushlc.station_measurements.quadkey=ndbc_measurements_joinable.quadkey AND ushlc.station_measurements.timestamp_tz=ndbc_measurements_joinable.hr
    WHERE ushlc.station_measurements.timestamp_tz BETWEEN @start_dt AND @end_dt
)
-- CREATE THE SWELL TAG FROM THE JOINED TABLE USING THE CLOSEST IN SPACE AND TIME RECORD.
SELECT 
    timestamp_tz as bouy_timestamp_tz, 
    station_id as bouy_station_id, 
    uh_id as tide_station_uh_id, 
    version as tide_station_version,
    hr as tide_station_timestamp_tz,
    quadkey,
    geometry as bouy_geometry,
    [
        wave_height::float,
        dominant_wave_period::float,
        average_wave_period::float,
        measured_wave_direction::float,
        coalesce((reading_mm/1000.0)::float, tide::float), -- prefer the ushlc but fallback when missing
        quadkey::float
    ]::float[6] AS swell_tag
FROM ndbc_ushlc_joined
WHERE closeness = 1 AND timestamp_tz BETWEEN @start_dt AND @end_dt
ORDER BY timestamp_tz, quadkey, station_id
