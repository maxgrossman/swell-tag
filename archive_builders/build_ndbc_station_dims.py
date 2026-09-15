from archive_builders.common import lambda_duck
duckdb = lambda_duck

BRONZE_SQL_DOWNLOAD = """
COPY (
WITH station_xml as
    (SELECT *, unnest(history) as hist
        FROM read_xml('https://www.ndbc.noaa.gov/metadata/stationmetadata.xml'))
SELECT
    row_number() over (partition by id order by hist.start asc) as station_sk,
    id as station_id,
    name,
    owner,
    pgm,
    type,
    strptime(hist.start, '%Y-%m-%d')::timestamptz as start_time,
    strptime(hist.stop, '%Y-%m-%d')::timestamptz as end_time,
    ST_Point(hist.lng::double, hist.lat::double) as geometry,
    h3_latlng_to_cell(hist.lat::double, hist.lng::double, 4) as h3_04,
    hist.elev::double as elev,
    hist.met as met,
    hist.hull as hull,
    hist.anemom_height::double as anemom_height
FROM station_xml
ORDER BY h3_04, station_id, start_time
) TO $s3_uri (FORMAT PARQUET)
"""

def write_ndbc_dims_to_s3(
    conn: duckdb.DuckDBPyConnection,
    s3_uri: str
):
    conn.load_extension('spatial')
    conn.load_extension('webbed')
    conn.load_extension('h3')
    conn.execute(BRONZE_SQL_DOWNLOAD, {'s3_uri': s3_uri})