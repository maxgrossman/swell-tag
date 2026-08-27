MODEL(
    name ushlc.station_measurements,
    kind INCREMENTAL_BY_TIME_RANGE (
        time_column timestamp_tz
    ),
    start '2000-01-01'
);

SET VARIABLE station_archives = (
    SELECT list(archive_url) FROM (
        FROM read_csv('data/ushlc.archive.csv') as arch_index
        JOIN ushlc.stations 
         ON ushlc.stations.uh_id=arch_index.uh_id 
        AND ushlc.stations.version=arch_index.version
        -- do that range intersection!
        WHERE start_time <= @end_dt AND end_time >= @start_dt
    )
);

SET threads=4;

with hrly as (
    select 
        filename[-8:-6] as uh_id, 
        filename[-5] as version,
        make_timestamptz(column0::bigint,column1::bigint,column2::bigint,column3::bigint,0::bigint,0.0,'utc') as timestamp_tz, 
        column4 as reading_mm 
    from read_csv(getvariable('station_archives'))
)
select 
    hrly.uh_id,
    hrly.version,
    hrly.timestamp_tz,
    hrly.reading_mm,
    ushlc.stations.geometry as geometry,
    ushlc.stations.h3_04
from hrly
join ushlc.stations on hrly.uh_id=ushlc.stations.uh_id and 
        hrly.version=ushlc.stations.version
where timestamp_tz between @start_dt and @end_dt
