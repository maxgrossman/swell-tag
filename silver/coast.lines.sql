LOAD aws;
LOAD httpfs;
LOAD spatial;

create schema if not exists coast;
drop table if exists coast.lines;
create table if not exists coast.lines (h3_04 uint64, geom geometry);
insert into coast.lines
select * from 's3://swell-tags-us-east-1/bronze/coast_lines.parquet';