MODEL (
  name coop.stations,
  kind FULL,
  columns (
    station_id varchar,
    station_name varchar,
    geometry geometry
  )
);

INSTALL spatial;
LOAD spatial;

with stations as (
    select 
        "Station ID" as station_id, 
        "Station Name" as station_name,  
        ST_Point(Longitude,Latitude) as geometry
    from read_csv('https://tidesandcurrents.noaa.gov/cdata/StationListFormat?type=Current+Data&filter=historic&format=csv') 
    union all
    select 
        "Station ID" as station_id, 
        "Station Name" as station_name,  
        ST_Point(Longitude,Latitude) as geometry
    from read_csv('https://tidesandcurrents.noaa.gov/cdata/StationListFormat?type=Current+Data&filter=active&format=csv')
)
select station_id, station_name, geometry
from stations;