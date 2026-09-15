import duckdb

STANDARD_MET_QUERY = """
WITH
standard_met_archive AS
    (SELECT name[:5] as station_id,
        'https://www.ndbc.noaa.gov/data/historical/stdmet/' || name as archive_url,
        name[7:10] as year
     FROM read_html('https://www.ndbc.noaa.gov/data/historical/stdmet/', 'table', 1)
     WHERE name not like '%Dir%'),

standard_met_this_year AS
    (SELECT Name[:5] as station_id,
            'https://www.ndbc.noaa.gov/data/l_stdmet/' || Name as archive_url,
            extract(year from Last_modified::timestamp) as year
        FROM read_html('https://www.ndbc.noaa.gov/data/l_stdmet/', 'table', 1)
        OFFSET 1),

standard_met_full_archive AS
    (SELECT * FROM standard_met_archive
        UNION ALL
     SELECT * FROM standard_met_this_year),

stations_metadata AS
    (SELECT * FROM read_xml('https://www.ndbc.noaa.gov/metadata/stationmetadata.xml'))

SELECT
    MAKE_TIMESTAMPTZ(
        year::bigint,
        1::bigint,
        1::bigint,
        0::bigint,
        0::bigint,
        0.0::double,
        'utc'::varchar
    ) as timestamp_tz,
    station_id,
    archive_url,
    's3://swell-tags/bronze/ndbc' || string_split(archive_url,'/')[-1] as s3_url
FROM standard_met_full_archive
JOIN stations_metadata
    ON stations_metadata.id = standard_met_full_archive.station_id
ORDER BY station_id, year
"""


def write_standard_met_to_csv(
    conn: duckdb.DuckDBPyConnection,
    output_path: str,
) -> None:
    """
    Query the NOAA standard meteorological archive and write the
    results to a local CSV file.

    Parameters
    ----------
    conn:
        An existing DuckDB Python connection.
    output_path:
        Local path for the output CSV, e.g. "./standard_met.csv".
    """
    # conn.install_extension("webbed",repository='community')
    conn.load_extension("webbed")
    # conn.install_extension("crawler",repository='community')
    conn.load_extension("crawler")
    conn.execute(
        f"""
        COPY (
            {STANDARD_MET_QUERY}
        )
        TO '{output_path}'
        (FORMAT CSV, HEADER TRUE)
        """
    )


def write_standard_met_to_s3(
    conn: duckdb.DuckDBPyConnection,
    s3_uri: str,
) -> None:
    """
    Query the NOAA standard meteorological archive and write the
    results directly to S3 using DuckDB's httpfs extension.

    Parameters
    ----------
    conn:
        An existing DuckDB Python connection.
    s3_uri:
        S3 destination, e.g.
        "s3://my-bucket/path/standard_met.csv".
    """
    # conn.install_extension("webbed",repository='community')
    conn.load_extension("webbed")
    # conn.install_extension("crawler",repository='community')
    conn.load_extension("crawler")

    conn.execute(
        f"""
        COPY (
            {STANDARD_MET_QUERY}
        )
        TO '{s3_uri}'
        (FORMAT CSV, HEADER TRUE)
        """
    )