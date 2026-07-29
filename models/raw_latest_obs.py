from sqlmesh import model, macro
from sqlmesh.core.model.kind import ModelKindName
from sqlmesh.core.node  import IntervalUnit, INTERVAL_SECONDS
from datetime import datetime, timedelta

import pandas as pd
import sqlmesh.cli as cli

MODEL_NAME="ndbc_duck.raw_measurements_latest_obs"
INTERVAL_NAME = 'five_minute'
LOOKBACK = int((48*60)/5) #2 days worth of late data allowed

@model(
    name=MODEL_NAME,
    kind={
        "name":ModelKindName.INCREMENTAL_BY_TIME_RANGE,
        "time_column": "timestamp_tz",
        "lookback": LOOKBACK
    },
    cron="*/5 * * * *",
    interval_unit=INTERVAL_NAME,
    start='2026-07-21',
    columns={
        "station_id": "varchar",
        "timestamp_tz": "timestamptz",
        "line": "varchar[]"
    }
)
def execute(context, start, end, **kwargs):
    # force the lookback
    lookback_seconds = LOOKBACK * 60 * 5
    start_fmt = (start-timedelta(seconds=lookback_seconds)).isoformat()
    end_fmt = end.isoformat()
    latest_obs_path = context.var('latest_obs_path', 'latest_obs')

    query = f"""
        WITH 
        parsed_lines AS 
            (SELECT str_split(regexp_replace(column0,'\s+',',', 'g'),',') AS line
             FROM read_csv('{latest_obs_path}/*',comment='#',header=false,skip=1)),
        -- since might see same observations in the latest obs, collapse those guys!
        table_lines as 
            (SELECT DISTINCT 
                    line[1] as station_id, 
                    MAKE_TIMESTAMPTZ(
                        line[4]::bigint,
                        line[5]::bigint,
                        line[6]::bigint,
                        line[7]::bigint,
                        -- invalid guys in here in some files.
                        case when line[8]::bigint >= 60 
                            then 0 
                            else line[8]::bigint end,
                        0.0,
                        'UTC'
                    ) as timestamp_tz, 
                    line[1:] as line
             FROM parsed_lines)
        -- the ole' left join null trick to keep out those rows we get a match on in the current
        -- latest_obs raw table.
        SELECT table_lines.station_id, table_lines.timestamp_tz, table_lines.line
        FROM table_lines
        LEFT JOIN ndbc_duck.raw_measurements_latest_obs
                ON ndbc_duck.raw_measurements_latest_obs.station_id=table_lines.station_id
                AND ndbc_duck.raw_measurements_latest_obs.timestamp_tz=table_lines.timestamp_tz
        WHERE ndbc_duck.raw_measurements_latest_obs.station_id IS NULL 
          AND table_lines.timestamp_tz BETWEEN '{start_fmt}' and '{end_fmt}'
        ORDER BY station_id, timestamp_tz asc
    """
    data_frame = context.fetchdf(query)
    if data_frame.empty:
        yield from ()
        return

    return data_frame
