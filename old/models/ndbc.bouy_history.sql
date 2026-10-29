MODEL(
    name ndbc_duck.bouy_history,
    kind FULL,
    columns (
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
    )
);

SET extension_directory = '/var/task';
LOAD aws;
LOAD httpfs;
LOAD spatial;
LOAD webbed;
LOAD h3;

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
from 's3://swell-tags-us-east-1/bronze/ndbc_station_dims.parquet'