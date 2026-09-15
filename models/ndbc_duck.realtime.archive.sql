MODEL(
    name ndbc_duck.archive_realtime,
    kind FULL,
    columns (
        station_id varchar,
        realtime_url varchar,
        start_time timestamptz,
        end_time timestamptz
    )
);

SET extension_directory = '/var/task';
LOAD webbed; LOAD crawler;

WITH
stations_realtime AS
    (SELECT
        Name[:5] AS station_id,
        'https://www.ndbc.noaa.gov/data/realtime2/' || Name AS realtime_url,
        date_trunc('day', current_timestamp - '45 days'::interval) as start_time,
        date_trunc('day', current_timestamp) as end_time
        FROM read_html('https://www.ndbc.noaa.gov/data/realtime2/', 'table',1)
     WHERE Description = 'Standard Meteorological Data'),
stations_metadata AS
    (SELECT * FROM read_xml('https://www.ndbc.noaa.gov/metadata/stationmetadata.xml'))
SELECT * from stations_realtime
JOIN stations_metadata ON stations_metadata.id = stations_realtime.station_id