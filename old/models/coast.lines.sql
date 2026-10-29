LOAD aws;
LOAD httpfs;
LOAD spatial;

create schema if not exists coast;
create table if not exists coast.lines (geom geometry);
select * from 's3://swell-tags-us-east-1/bronze/coast_lines.parquet';