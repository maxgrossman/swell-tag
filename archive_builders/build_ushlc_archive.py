import duckdb

UH_SLC_QUERY = """
WITH urls AS (
    SELECT
        'https://uhslc.soest.hawaii.edu/data/csv/rqds/atlantic/hourly/'
            || unnest(pre.a).href AS archive_url,
        unnest(pre.a).href AS href
    FROM read_html(
        'https://uhslc.soest.hawaii.edu/data/csv/rqds/atlantic/hourly/'
    )

    UNION ALL

    SELECT
        'https://uhslc.soest.hawaii.edu/data/csv/rqds/indian/hourly/'
            || unnest(pre.a).href AS archive_url,
        unnest(pre.a).href AS href
    FROM read_html(
        'https://uhslc.soest.hawaii.edu/data/csv/rqds/indian/hourly/'
    )

    UNION ALL

    SELECT
        'https://uhslc.soest.hawaii.edu/data/csv/rqds/pacific/hourly/'
            || unnest(pre.a).href AS archive_url,
        unnest(pre.a).href AS href
    FROM read_html(
        'https://uhslc.soest.hawaii.edu/data/csv/rqds/pacific/hourly/'
    )
)

SELECT
    archive_url[-8:-6] AS uh_id,
    archive_url[-5] AS version,
    archive_url,
    's3://swell-tags/bronze/ushlc/' || string_split(archive_url,'/')[-1] as s3_url
FROM urls
WHERE href != '../'
"""

def write_uh_slc_to_csv(
    conn: duckdb.DuckDBPyConnection,
    output_path: str,
) -> None:
    """
    Query the UH Sea Level Center archive and write the results
    to a local CSV file.

    Parameters
    ----------
    conn:
        An existing DuckDB Python connection.
    output_path:
        Local path for the output CSV.
    """
    # conn.install_extension("webbed",repository='community')
    conn.load_extension("webbed")

    conn.execute(
        f"""
        COPY (
            {UH_SLC_QUERY}
        )
        TO '{output_path}'
        (FORMAT CSV, HEADER TRUE)
        """
    )


def write_uh_slc_to_s3(
    conn: duckdb.DuckDBPyConnection,
    s3_uri: str,
) -> None:
    """
    Query the UH Sea Level Center archive and write the results
    directly to S3.

    Parameters
    ----------
    conn:
        An existing DuckDB Python connection.
    s3_uri:
        S3 destination, e.g.
        "s3://my-bucket/uhslc/hourly_archives.csv".
    """
    # Required for writing to S3.
    # conn.install_extension("httpfs")
    conn.load_extension("httpfs")
    # conn.install_extension("webbed",repository='community')
    conn.load_extension("webbed")

    conn.execute(
        f"""
        COPY (
            {UH_SLC_QUERY}
        )
        TO '{s3_uri}'
        (FORMAT CSV, HEADER TRUE)
        """
    )
