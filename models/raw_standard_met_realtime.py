from sqlmesh import model, macro
from sqlmesh.core.model.kind import ModelKindName
from datetime import datetime

import sqlmesh.cli as cli
import pandas as pd
import json

@model(
    name="ndbc_duck.raw_measurements_realtime",
    kind={
        "name":ModelKindName.INCREMENTAL_BY_TIME_RANGE,
        "time_column": "timestamp_tz"
    },
    cron='@hourly',
    start='2000-01-01',
    columns={
        "station_id": "varchar",
        "timestamp_tz": "timestamptz",
        "line": "varchar[]"
    }
)
def execute(context, start, end, **kwargs):
    # so to not ham sammy requests to ndbc, 4 threads will work.
    # also, since these are real time files, if we stream the thing and the data changes, the etag will be different
    # and duckdb will scream at us. downing 4 of these files which are only couple hundred kb is w/e
    context.fetchdf("SET threads=4; SET force_download=true"); 
    # get the station archive urls to download, format those guys to put in the read_csv func
    start_fmt = start.strftime('%Y-%m-%d')
    end_fmt = end.strftime('%Y-%m-%d')

    station_realtime = context.fetchdf(f"""
        select realtime_url from read_csv('data/ndbc.realtime.csv') 
        where start_time between '{start_fmt}' and '{end_fmt}'
          and end_time between '{start_fmt}' and '{end_fmt}'
    """)['realtime_url']

    stations_realtime_list = list(station_realtime)

    if not stations_realtime_list:
        yield from ()
        return

    station_realtime_list = json.dumps(stations_realtime_list)

    query = f"""
        WITH parsed_lines AS 
            (SELECT str_split(filename,'realtime2/')[2][:5] AS station_id, 
                    str_split(regexp_replace(column0,'\s+',',', 'g'),',') AS line
            FROM read_csv({station_realtime_list},comment='#',header=false,skip=1)),
        -- go get the max timestamp we have from the historical archive.
        max_station_lines AS 
            (SELECT station_id, max(timestamp_tz) AS max_timestamp_tz
            FROM ndbc_duck.raw_measurements
            GROUP BY station_id),
        table_lines AS 
            (SELECT station_id, 
                    MAKE_TIMESTAMPTZ(
                        line[1]::bigint,
                        line[2]::bigint,
                        line[3]::bigint,
                        line[4]::bigint,
                        line[5]::bigint,
                        -- invalid guys in here in some files.
                        case when line[5]::bigint >= 60 
                            then 0 
                            else line[5]::bigint end,
                        0.0,
                        'UTC'
                    ) as timestamp_tz, 
                    line
            FROM parsed_lines)
        --  only keep lines from realtime that are newer than the last archived date since they can intersect.
        SELECT table_lines.station_id, table_lines.timestamp_tz, table_lines.line
        FROM max_station_lines
        INNER JOIN table_lines
        ON max_station_lines.station_id = table_lines.station_id
        AND max_station_lines.max_timestamp_tz < table_lines.timestamp_tz
        WHERE timestamp_tz BETWEEN '{start_fmt}' and '{end_fmt}'
        ORDER BY station_id, timestamp_tz asc
    """
    return context.fetchdf(query)
