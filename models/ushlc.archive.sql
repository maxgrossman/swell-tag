MODEL(
    name ushlc.archive, 
    kind FULL,
    columns (
        uh_id varchar,
        version varchar,
        archive_url varchar
    )
);

SELECT * FROM read_csv('s3://swell-tags/ushlc_archive.csv')