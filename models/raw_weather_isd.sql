MODEL(
    name isd_duck.raw_measurements_isd,
    kind INCREMENTAL_BY_TIME_RANGE (
        time_column timestamp_tz
    ),
    start '2000-01-01',
    columns (
        station varchar,
        timestamp_tz timestamptz,
        geometry geometry,
        quadkey varchar,
        source varchar,
        report_type varchar,
        quality_control varchar,
        wnd varchar,
        cig varchar,
        vis varchar,
        tmp varchar,
        dew varchar,
        slp varchar
    )
);

INSTALL httpfs; LOAD httpfs;
INSTALL spatial; LOAD spatial;

set variable stations_archives_list = (
    select list(archive_url) from (
        select archive_url from 'data/isd.archive.parquet' 
        where timestamp_tz between @start_dt and @end_dt
        and quadkey[:(SELECT length(@parent_quadkey))] == @parent_quadkey
    )
);

WITH 
station_archives as 
    (SELECT
        station,
        date,
        source,
        report_type,
        quality_control,
        latitude,
        longitude,
        wnd,
        cig,
        vis,
        tmp,
        dew,
        slp
        FROM read_csv(getvariable('stations_archives_list'), union_by_name=true))
SELECT
    station_archives.station::varchar as station,
    station_archives.date::timestamptz at time zone 'utc' as timestamp_tz,
    ST_Point(station_archives.longitude::double, station_archives.latitude::double) as geometry,
    ST_QuadKey(ST_Point(station_archives.longitude::double, station_archives.latitude::double), 8) as quadkey,
    station_archives.source::varchar as source,
    station_archives.report_type as report_type,
    station_archives.quality_control as quality_control,
    station_archives.wnd as wnd,
    station_archives.cig as cig,
    station_archives.vis as vis,
    station_archives.tmp as tmp,
    station_archives.dew as dew,
    station_archives.slp as slp
FROM isd_duck.weather_stations
JOIN station_archives 
    ON station_archives.station = isd_duck.weather_stations.station
WHERE timestamp_tz BETWEEN @start_dt and @end_dt
ORDER BY quadkey, timestamp_tz, station