MODEL (
  name ushlc.stations,
  kind FULL
);

INSTALL spatial; LOAD spatial;
INSTALL crawler from community; LOAD crawler;
INSTALL h3 from community; LOAD h3;

select
  "UH#" as uh_id,
  "GLOSS#" as gloss_id,
  Version as version,
  Location as location,
  Country as country,
  ST_Point(Longitude, Latitude) as geometry,
  h3_latlng_to_cell(Latitude,Longitude,4) as h3_04,
  (Start || 'T00:00:00+00:00')::timestamptz as start_time,
  (End || 'T00:00:00+00:00')::timestamptz as end_time
from read_html('https://uhslc.soest.hawaii.edu/data/rq.html?_=1785295960968', 'table');