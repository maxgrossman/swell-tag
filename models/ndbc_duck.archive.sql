MODEL(
    name ndbc_duck.archive,
    kind FULL,
    columns (
        timestamp_tz timestamptz,
        station_id varchar,
        archive_url varchar
    )

);

SET extension_directory = '/var/task';
LOAD aws;
LOAD httpfs;

SELECT * FROM 's3://swell-tags-us-east-1/bronze/ndbc_archive.csv'