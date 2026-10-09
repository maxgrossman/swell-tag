LOAD aws;
LOAD httpfs;
LOAD spatial;
LOAD crawler;
LOAD h3;

create schema if not exists ushlc;
create table if not exists ushlc.stations (
    uh_id                              bigint,
    gloss_id                           bigint,
    version                            varchar,
    location                           varchar,
    country                            varchar,
    geometry                           geometry,
    h3_04                              ubigint,
    start_time                         timestamp with time zone,
    end_time                           timestamp with time zone
);
insert into ushlc.stations
select * from 's3://swell-tags-us-east-1/bronze/ushlc_station_dims.parquet' s_stations
anti join ushlc.stations t_stations on
    t_stations.uh_id = s_stations.uh_id and
    t_stations.version = s_stations.version and
    t_stations.gloss_id = s_stations.gloss_id;
