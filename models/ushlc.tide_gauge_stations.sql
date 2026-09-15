MODEL (
  name ushlc.stations,
  kind FULL
);

SET extension_directory = '/var/task';
LOAD aws;
LOAD httpfs;
LOAD spatial;
LOAD crawler;
LOAD h3;

select * from 's3://swell-tags-us-east-1/bronze/ushlc_station_dims.parquet'