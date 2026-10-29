MODEL(
    name ndbc_duck.archive,
    kind FULL,
    columns (
        timestamp_tz timestamptz,
        station_id varchar,
        archive_url varchar,
        s3_url varchar
    )

);

LOAD aws;
LOAD httpfs;

SELECT timestamp_tz, station_id, archive_url, s3_url FROM 's3://swell-tags-us-east-1/bronze/ndbc_archive.csv'