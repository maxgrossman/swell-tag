LOAD aws;
LOAD httpfs;
LOAD spatial;
LOAD webbed;
LOAD h3;

create schema if not exists ndbc;
create table if not exists ndbc.bouy_history (
    station_sk int,
    station_id varchar,
    name varchar,
    owner varchar,
    pgm varchar,
    type varchar,
    start_time timestamptz,
    end_time timestamptz,
    geometry geometry,
    h3_04 uint64,
    elev double,
    met varchar,
    hull varchar,
    anemom_height double
);

INSERT INTO ndbc.bouy_history
select
    station_sk,
    station_id,
    name,
    owner,
    pgm,
    type,
    start_time,
    end_time,
    geometry,
    h3_04,
    elev,
    met,
    hull,
    anemom_height,
from 's3://swell-tags-us-east-1/bronze/ndbc_station_dims.parquet' s_bouy_history
ANTI JOIN ndbc.bouy_history t_bouy_history
ON t_bouy_history.station_sk = s_bouy_history.station_sk and t_bouy_history.station_id = s_bouy_history.station_id