MODEL (
  name ushlc.stations,
  kind FULL
);

INSTALL spatial;
LOAD spatial;
INSTALL crawler from community;
LOAD crawler;

select
  "UH#" as uh_id,
  "GLOSS#" as gloss_id,
  Version as version,
  Location as location,
  Country as country,
  ST_Point(Longitude, Latitude) as geometry,
  ST_Quadkey(geometry, 8) as quadkey,
  (Start || 'T00:00:00+00:00')::timestamptz as start_time,
  (End || 'T00:00:00+00:00')::timestamptz as end_time
from read_html('https://uhslc.soest.hawaii.edu/data/rq.html?_=1785295960968', 'table');