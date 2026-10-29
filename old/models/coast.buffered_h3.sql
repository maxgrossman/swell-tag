MODEL(
    name coast.buffered_h3,
    kind full,
    columns (
        h3_04 uint64,
        geom geometry
    )
);

LOAD aws;
LOAD httpfs;
LOAD h3;
LOAD spatial;
select geom, unnest(h3_polygon_wkt_to_cells(st_aswkt(st_buffer(geom, .6)), 4)) as h3_04
from 's3://swell-tags-us-east-1/bronze/coast_h3s.parquet'