MODEL(
    name ndbc_duck.bouy_history,
    kind FULL,
    columns (
        station_sk int,
        station_id varchar,
        name varchar,
        owner varchar,
        pgm varchar,
        type varchar,
        start_time timestamptz,
        end_time timestamptz,
        geometry geometry,
        h3_04 uint64,
        elev double,
        met varchar,
        hull varchar,
        anemom_height double
    )
);
  
INSTALL spatial; LOAD spatial;
INSTALL webbed FROM community; LOAD webbed; 
INSTALL h3 FROM community; LOAD h3; 

WITH station_xml as 
    (SELECT *, unnest(history) as hist
        FROM read_xml('https://www.ndbc.noaa.gov/metadata/stationmetadata.xml'))
SELECT 
    row_number() over (partition by id order by hist.start asc) as station_sk,
    id as station_id,
    name,
    owner,
    pgm,
    type,
    strptime(hist.start, '%Y-%m-%d')::timestamptz as start_time,
    strptime(hist.stop, '%Y-%m-%d')::timestamptz as end_time,
    ST_Point(hist.lng::double, hist.lat::double) as geometry,
    h3_latlng_to_cell(hist.lat::double, hist.lng::double, 4) as h3_04,
    hist.elev::double as elev,
    hist.met as met,
    hist.hull as hull,
    hist.anemom_height::double as anemom_height
FROM station_xml
ORDER BY h3_04, station_id, start_time