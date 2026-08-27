MODEL(
    name coops.station_measurements,
    kind INCREMENTAL_BY_TIME_RANGE (
        time_column timestamp_tz
    ),
    start '2000-01-01',
    columns (
        station_id varchar,
        h3_05 uint64,
        timestamp_tz timestamptz,
        water_level_m double,
    )
);

SET threads = 4;
INSTALL h3 from community;
LOAD h3;
INSTALL spatial;
LOAD spatial;

SET VARIABLE station_archives = (
    SELECT list(archive_url) FROM (
        SELECT 'https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?product=predictions&begin_date=' ||
                strftime(@start_dt, '%Y%m%d') || '&end_date=' || strftime(@end_dt, '%Y%m%d') ||
                '&datum=MLLW&station=' || station_id ||
                '&time_zone=GMT&units=english&interval=&format=csv&application=NOS.COOPS.TAC.WL' as archive_url
        FROM read_csv('data/coops.archive.csv')
        WHERE time_start <= @end_dt and 
              time_end >= @start_dt and
              ST_Within(ST_GeomFromText(geom), ST_GeomFromText(@VAR('parent_bbox', 'POLYGON((-180 -90, 180 -90, 180 90,, -180 90, -180 -90))')))
    )
);

--load station and geom
with archive as (select station_id, st_geomfromtext(geom) as geom from read_csv('data/coops.archive.csv'))
--read the csvs from coops; join back on station id to get that h3 cell
select station_id, h3_latlng_to_cell(st_y(geom),st_x(geom),5) as h3_05,
       ("Date Time"::varchar || '+00:00')::timestamptz as timestamp_tz, 
       Prediction as water_level_m
from read_csv(getvariable('station_archives'))
join archive on archive.station_id=str_split(str_split(filename,'station=')[2],'&')[1]
order by h3_08, timestamp_tz asc