from sqlmesh import model, macro
from sqlmesh.core.model.kind import ModelKindName
from datetime import datetime

import sqlmesh.cli as cli
import json

@model(
    name="ndbc_duck.raw_measurements",
    kind={
        "name":ModelKindName.INCREMENTAL_BY_TIME_RANGE,
        "time_column": "timestamp_tz"
    }, 
    start='2000-01-01',
    columns={
        "station_id": "varchar",
        "timestamp_tz": "timestamptz",
        "line": "varchar[]"
    }
)
def execute(context, start, end, **kwargs):
    context.fetchdf("SET threads=4"); # so to not ham sammy requests to ndbc, 2 threads will work.
    # get the station archive urls to download, format those guys to put in the read_csv func
    start_fmt = start.isoformat()
    end_fmt = end.isoformat()

    station_archives = context.fetchdf(f"""
        SELECT archive_url 
        FROM read_csv('data/ndbc.archive.csv')
        WHERE timestamp_tz BETWEEN '{start_fmt}' AND '{end_fmt}'
    """)['archive_url']

    station_archives_list = list(station_archives)

    # if not station_archives_list:
    #     yield from ()
    #     return

    station_archives_list = json.dumps(station_archives_list)

    query = f"""
    WITH 
    parsed_lines as 
        (SELECT str_split(filename,'stdmet/')[2][:5] as station_id, 
                str_split(regexp_replace(column0,'\s+',',', 'g'),',') as line
         FROM read_csv({station_archives_list}, comment='#', header=false, skip=1)),
    table_lines as 
        (SELECT station_id, 
                MAKE_TIMESTAMPTZ(
                    line[1]::bigint,
                    line[2]::bigint,
                    line[3]::bigint,
                    line[4]::bigint,
                    -- invalid guys in here in some files.
                    case when line[5]::bigint >= 60 
                         then 0 
                         else line[5]::bigint end,
                    0.0::double,
                    'UTC'
                ) as timestamp_tz, 
                line
         FROM parsed_lines)
    SELECT station_id, timestamp_tz, line
    FROM table_lines
    WHERE timestamp_tz BETWEEN '{start_fmt}'::timestamptz and '{end_fmt}'::timestamptz
    ORDER BY station_id, timestamp_tz;
    """
    return context.fetchdf(query) 
