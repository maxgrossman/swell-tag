from sqlmesh import model, macro
from sqlmesh.core.model.kind import ModelKindName
from datetime import datetime
from sqlglot import exp


import json

@model(
    name="ndbc_duck.bouy_history",
    kind={
        "name":ModelKindName.FULL,
    }, 
    columns={
        "station_sk": "int",
        "station_id": "varchar",
        "name": "varchar",
        "owner": "varchar",
        "pgm": "varchar",
        "type": "varchar",
        "start_time": "timestamptz",
        "end_time": "timestamptz",
        "geometry": "blob",
        "elev": "double",
        "met": "varchar",
        "hull": "varchar",
        "anemom_height": "double"
    }
)
def execute(context, **kwargs):
    query = f"""
    INSTALL spatial; INSTALL webbed FROM community;
    LOAD webbed; LOAD spatial;

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
        hist.elev::double as elev,
        hist.met as met,
        hist.hull as hull,
        hist.anemom_height::double as anemom_height
    FROM station_xml
    ORDER BY station_id, start_time
    """
    return context.fetchdf(query)