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

SELECT * FROM read_csv('s3://swell-tags/ushlc_archive.csv')