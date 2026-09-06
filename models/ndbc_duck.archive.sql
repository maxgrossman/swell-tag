MODEL(
    name ndbc_duck.archive, 
    kind FULL,
    columns (
        timestamp_tz timestamptz,
        station_id varchar,
        archive_url varchar
    )
    
);

SELECT * FROM read_csv('s3://swell-tags/ndbc_archive.csv')