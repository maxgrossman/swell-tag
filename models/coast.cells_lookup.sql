MODEL(
    name coast.cells_lookup,
    kind full,
    columns (
        lats double[],
        lons double[]
    )
);

SET extension_directory = '/var/task';
LOAD aws;
LOAD httpfs;
LOAD spatial;

select * from 's3://swell-tags-us-east-1/bronze/coast_lookups.parquet'