MODEL(
    name coast.lines,
    kind full,
    columns (
        geom geometry
    )
);

SET extension_directory = '/var/task';
LOAD aws;
LOAD httpfs;
LOAD spatial;

select * from 's3://swell-tags-us-east-1/bronze/coast_lines.parquet';