from sqlmesh import model
from sqlmesh.core.model.kind import ModelKindName

import sqlmesh.cli as cli



@model(
    name="ushlc.station_measurements",
    kind={
        "name":ModelKindName.INCREMENTAL_BY_TIME_RANGE,
        "time_column": "timestamp_tz"
    }, 
    start='2000-01-01',
    columns={
        "uh_id": "varchar",
        "version": "varchar",
        "timestamp_tz": "timestamptz",
        "reading_mm": "int",
        "geometry": "blob",
        "quadkey": "varchar"
    },
    depends_on=["ushlc.stations"]
)
def execute(context, start, end, **kwargs):
    # context.fetchdf("SET threads=8"); # so to not ham sammy requests to ndbc, 2 threads will work.
    # get the station archive urls to download, format those guys to put in the read_csv func
    start_fmt = start.isoformat()
    end_fmt = end.isoformat()

    station_archives = context.fetchdf(f"""
        SELECT archive_url
        FROM read_csv('data/ushlc.archive.csv') as arch_index
        JOIN ushlc.stations ON ushlc.stations.uh_id=arch_index.uh_id and ushlc.stations.version=arch_index.version
        -- do that range intersection!
        WHERE start_time <= '{end_fmt}' and end_time >= '{start_fmt}'
    """)['archive_url']

    station_archives_list = list(station_archives)

    query = f"""
        with hrly as (
            select 
                filename[-8:-6] as uh_id, 
                filename[-5] as version,
                make_timestamptz(column0::bigint,column1::bigint,column2::bigint,column3::bigint,0::bigint,0.0,'utc') as timestamp_tz, 
                column4 as reading_mm 
            from read_csv({station_archives_list})
        )
        select 
            hrly.uh_id,
            hrly.version,
            hrly.timestamp_tz,
            hrly.reading_mm,
            ushlc.stations.geometry as geometry,
            ushlc.stations.quadkey as quadkey
        from hrly
        join ushlc.stations on hrly.uh_id=ushlc.stations.uh_id and 
             hrly.version=ushlc.stations.version
        where timestamp_tz between '{start_fmt}' and '{end_fmt}'
    """
    return context.fetchdf(query) 