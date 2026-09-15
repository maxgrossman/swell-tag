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
load h3; load spatial;
select * from 's3://swell-tags-us-east-1/bronze/coast_h3s.parquet'