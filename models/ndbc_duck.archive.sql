MODEL(
    name ndbc_duck.archive, 
    kind FULL,
    columns (
        timestamp_tz timestamptz,
        station_id varchar,
        archive_url varchar
    )
    
);

INSTALL webbed FROM community; INSTALL crawler FROM community;
LOAD webbed; LOAD crawler;

WITH 
standard_met_archive AS 
    (SELECT name[:5] as station_id, 
        'https://www.ndbc.noaa.gov/data/historical/stdmet/' || name as archive_url, 
        name[7:10] as year
     FROM read_html('https://www.ndbc.noaa.gov/data/historical/stdmet/', 'table', 1)
     WHERE name not like '%Dir%'),
standard_met_this_year AS
    (SELECT Name[:5] as station_id,
            'https://www.ndbc.noaa.gov/data/l_stdmet/' || Name as archive_url,
            extract(year from Last_modified::timestamp) as year
        FROM read_html('https://www.ndbc.noaa.gov/data/l_stdmet/', 'table',1)
        OFFSET 1),
standard_met_full_archive AS
    (SELECT * FROM standard_met_archive 
        UNION ALL 
        SELECT * FROM standard_met_this_year),
stations_metadata AS
    (SELECT * FROM read_xml('https://www.ndbc.noaa.gov/metadata/stationmetadata.xml'))
SELECT
    MAKE_TIMESTAMPTZ(year::bigint,
        1::bigint,
        1::bigint,
        0::bigint,
        0::bigint,
        0.0::double,
        'utc'::varchar
    ) as timestamp_tz,      
    station_id, 
    archive_url
FROM standard_met_full_archive
JOIN stations_metadata on stations_metadata.id = standard_met_full_archive.station_id
ORDER by station_id, year