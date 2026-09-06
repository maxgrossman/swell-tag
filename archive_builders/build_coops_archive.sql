INSTALL crawler from community;
LOAD crawler;
INSTALL webbed from community;
LOAD webbed;
INSTALL spatial;
LOAD spatial;
INSTALL h3 from community;
LOAD h3;

SET GLOBAL crawler_timeout_ms = 60000; -- 15 seconds
SET GLOBAL threads = 4;
SET variable linkies = (
    select list(links) from (
        select 'https://opendap.co-ops.nos.noaa.gov/axis/webservices/datainventory/response.jsp?stationId=' || id || '&format=html&Submit=Submit' as links
        from (select id, name, geom from st_read('data/coops.hist.geojson') union all
              select id, name, geom from st_read('data/coops.act.geojson'))
    )
);

COPY (
    with 
    xml_docs as (
        select xml_to_json(html['document'])::json as page_json
        from crawl(getvariable('linkies'))
    ), 
    xml_parameters as (
        select 
            json_extract(page_json,'$.Envelope.Body.DataInventory.station.@ID')::varchar as station_id,
            json_extract(page_json,'$.Envelope.Body.DataInventory.station.metadata.location.long.#text')::varchar as lon,
            json_extract(page_json,'$.Envelope.Body.DataInventory.station.metadata.location.lat.#text')::varchar as lat,
            list_filter(list_zip(
                json_extract(page_json,'$.Envelope.Body.DataInventory.station.parameter[*].@name'),
                json_extract(page_json,'$.Envelope.Body.DataInventory.station.parameter[*].@first'),
                json_extract(page_json,'$.Envelope.Body.DataInventory.station.parameter[*].@last')
            ), lambda l: l[1] = '"Verified 6-Minute Water Level"')[1] as tide_range
        from xml_docs
    )
    select 
        replace(station_id, '"'::varchar, ''::varchar) as station_id,
        st_point(
            replace(lon, '"'::varchar,''::varchar)::double, 
            replace(lat,'"'::varchar,''::varchar)::double
        ) as geom,  
        strptime(
            replace((tide_range::json->'*')[2]::varchar || '+00:00', '"'::varchar,''::varchar),
            '%Y-%m-%d %H:%M%z'
        )::timestamptz as time_start, 
        strptime(
            replace((tide_range::json->'*')[3]::varchar || '+00:00', '"'::varchar,''::varchar),
            '%Y-%m-%d %H:%M%z'
        )::timestamptz as time_end
    from xml_parameters
) TO 'data/coops.archive.csv'
