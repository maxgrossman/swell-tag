from sqlmesh import model
from sqlmesh.core.model.kind import ModelKindName

import sqlmesh.cli as cli



@model(
    name="isd_duck.raw_measurements_isd",
    kind={
        "name":ModelKindName.INCREMENTAL_BY_TIME_RANGE,
        "time_column": "timestamp_tz"
    }, 
    depends_on=[
        "isd_duck.weather_stations"
    ],
    start='2000-01-01',
    columns={
        "station": "varchar",
        "timestamp_tz": "timestamptz",
        "geometry": "blob",
        "quadkey": "varchar",
        "source": "varchar",
        "report_type": "varchar",
        "quality_control": "varchar",
        "wnd": "varchar",
        "cig": "varchar",
        "vis": "varchar",
        "tmp": "varchar",
        "dew": "varchar",
        "slp": "varchar"
    }
)
def execute(context, start, end, **kwargs):
    # context.fetchdf("SET threads=8"); # so to not ham sammy requests to ndbc, 2 threads will work.
    # get the station archive urls to download, format those guys to put in the read_csv func
    start_fmt = start.isoformat()
    end_fmt = end.isoformat()
    parent_quadkey = context.var("parent_quadkey", "")

    station_archives = context.fetchdf(f"""
        SELECT archive_url 
        FROM 'data/isd.archive.parquet'
        WHERE timestamp_tz BETWEEN '{start_fmt}' AND '{end_fmt}'
          AND quadkey[:{str(len(parent_quadkey))}] == '{parent_quadkey}'
          -- ^^ so that we can test on smaller subsets of the weather data
          --    we put a quadkey on the indexes. then when i plan, can just plotz in 
          --    quadkey i want to query on...
    """)['archive_url']

    station_archives_list = list(station_archives)

    query = f"""
    INSTALL httpfs; LOAD httpfs;
    INSTALL spatial; LOAD spatial;
    WITH 
    station_archives as 
        (SELECT
            station,
            date,
            source,
            report_type,
            quality_control,
            latitude,
            longitude,
            wnd,
            cig,
            vis,
            tmp,
            dew,
            slp
         FROM read_csv({station_archives_list}, union_by_name=true))
    SELECT
        station_archives.station::varchar as station,
        station_archives.date::timestamptz at time zone 'utc' as timestamp_tz,
        ST_Point(station_archives.longitude::double, station_archives.latitude::double) as geometry,
        ST_QuadKey(ST_Point(station_archives.longitude::double, station_archives.latitude::double), 8) as quadkey,
        station_archives.source::varchar as source,
        station_archives.report_type as report_type,
        station_archives.quality_control as quality_control,
        station_archives.wnd as wnd,
        station_archives.cig as cig,
        station_archives.vis as vis,
        station_archives.tmp as tmp,
        station_archives.dew as dew,
        station_archives.slp as slp
    FROM isd_duck.weather_stations
    JOIN station_archives 
      ON station_archives.station = isd_duck.weather_stations.station
    WHERE timestamp_tz BETWEEN '{start_fmt}'::timestamptz and '{end_fmt}'::timestamptz
    ORDER BY quadkey, timestamp_tz, station
    """
    return context.fetchdf(query) 