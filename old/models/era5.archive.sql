MODEL(
    name era5_duck.archive,
    kind FULL,
    columns (
        start_timestamp_tz timestamptz,
        end_timestamp_tz timestamptz,
        archive_url varchar,
        s3_url varchar
    )
);

LOAD aws;
LOAD httpfs;

SELECT * FROM 's3://swell-tags-us-east-1/bronze/era5_archive.csv'