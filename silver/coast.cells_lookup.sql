LOAD aws;
LOAD httpfs;
LOAD spatial;

create schema if not exists coast;
drop table if exists coast.cell_lookups;
create table if not exists coast.cell_lookups (lats double[], lons double[]);

insert into coast.cell_lookups
select * from 's3://swell-tags-us-east-1/bronze/coast_lookups.parquet'