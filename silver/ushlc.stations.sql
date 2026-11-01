LOAD aws;
LOAD httpfs;
LOAD spatial;
LOAD crawler;
LOAD h3;

create schema if not exists ushlc;
drop table if exists ushlc.stations;
create table if not exists ushlc.stations (
uh_id                              bigint,
gloss_id                           bigint,
version                            varchar,
station_id                         varchar,
location                           varchar,
country                            varchar,
geometry                           geometry,
h3_04                              ubigint,
start_time                         timestamp with time zone,
end_time                           timestamp with time zone
);
insert into ushlc.stations select * from 's3://swell-tags-us-east-1/bronze/ushlc_station_dims.parquet'
