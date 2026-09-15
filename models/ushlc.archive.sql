MODEL(
    name ushlc.archive,
    kind FULL,
    columns (
        uh_id varchar,
        version varchar,
        archive_url varchar
    )
);

LOAD aws;
LOAD httpfs;

SELECT uh_id, version, archive_url FROM 's3://swell-tags-us-east-1/bronze/ushlc_archive.csv'