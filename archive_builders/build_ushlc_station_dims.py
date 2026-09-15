from archive_builders.common import lambda_duck
duckdb = lambda_duck

BRONZE_SQL_DOWNLOAD = """
COPY (
select
  "UH#" as uh_id,
  "GLOSS#" as gloss_id,
  Version as version,
  Location as location,
  Country as country,
  ST_Point(Longitude, Latitude) as geometry,
  h3_latlng_to_cell(Latitude,Longitude,4) as h3_04,
  ("Start" || 'T00:00:00+00:00')::timestamptz as start_time,
  ("End" || 'T00:00:00+00:00')::timestamptz as end_time
from read_html('https://uhslc.soest.hawaii.edu/data/rq.html?_=1785295960968', 'table')
) TO $s3_uri
"""

def write_uhslc_dims_to_s3(
    conn: duckdb.DuckDBPyConnection,
    s3_uri: str
):
    conn.load_extension('h3')
    conn.load_extension('spatial')
    conn.load_extension('crawler')
    conn.execute(BRONZE_SQL_DOWNLOAD, {'s3_uri': s3_uri})