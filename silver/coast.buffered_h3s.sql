LOAD aws;
LOAD httpfs;
LOAD h3;
LOAD spatial;

create schema if not exists coast;
drop table if exists coast.buffered_h3s;
create table if not exists coast.buffered_h3s (geom geometry, h3_04 uint64);
insert into coast.buffered_h3s
select geom, unnest(h3_polygon_wkt_to_cells(st_aswkt(st_buffer(geom, .6)), 4)) as h3_04
from 's3://swell-tags-us-east-1/bronze/coast_h3s.parquet';