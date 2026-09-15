MODEL(
    name era5_duck.archive,
    kind FULL,
    columns (
        start_timestamp_tz timestamptz,
        end_timestamp_tz timestamptz,
        archive_url varchar,
        parquet_path varchar
    )
);

SET extension_directory = '/var/task';
LOAD aws;
LOAD httpfs;

SELECT * FROM 's3://swell-tags-us-west-2/bronze/era5_archive.csv'