from sqlmesh import model
from sqlmesh.core.model.kind import ModelKindName


@model(
    name="isd_duck.weather_stations",
    kind={
        "name":ModelKindName.FULL
    }, 
    columns={
        "station_sk": "int",
        "station": "varchar",
        "usaf_id": "varchar",
        "wban_num": "varchar",
        "station_name": "varchar",
        "fips_country": "varchar",
        "us_state": "varchar",
        "icao": "varchar",
        "geometry": "blob",
        "elev": "double",
        "report_start": "timestamptz",
        "report_end": "timestamptz"
    }
)
def execute(context, **kwargs):
    query = f"""
    INSTALL spatial; INSTALL webbed FROM community;
    LOAD webbed; LOAD spatial;
    WITH 
    isd_stations AS (
        SELECT * from read_csv('https://www.ncei.noaa.gov/pub/data/noaa/isd-history.txt', skip=19)
    ),
    str_positions AS (
        SELECT 
            strpos(column0, 'USAF') AS usaf_pos,
            strpos(column0, 'WBAN') AS wban_pos,
            strpos(column0, 'STATION NAME') AS station_pos,
            strpos(column0, 'CTRY') AS ctry_pos,
            strpos(column0, regexp_extract(column0, 'ST\s+CALL')) AS st_pos,
            strpos(column0, 'CALL') AS call_pos,
            strpos(column0, 'LAT') AS lat_pos,
            strpos(column0, 'LON') AS lon_pos,
            strpos(column0, 'ELEV(M)') AS elev_pos,
            strpos(column0, 'BEGIN') AS begin_pos,
            strpos(column0, 'END') AS end_pos
        FROM isd_stations
        LIMIT 1
    ),
    str_positions_joined AS (
        SELECT
            column0,
            str_positions.*
        FROM isd_stations
        JOIN str_positions on true = true
        OFFSET 2
    ),
    raw_columns AS (
        SELECT 
            trim(column0[usaf_pos:wban_pos-1]) AS usaf_id,
            trim(column0[wban_pos:station_pos-1]) AS wban_num,
            trim(column0[station_pos:ctry_pos-1]) AS station_name,
            trim(column0[ctry_pos:st_pos-1]) AS fips_country,
            trim(column0[st_pos:call_pos-1]) AS us_state,
            trim(column0[call_pos:lat_pos-1]) AS icao,
            trim(column0[lat_pos:lon_pos-1]) AS lat,
            trim(column0[lon_pos:elev_pos-1]) AS lon,
            trim(column0[elev_pos:begin_pos-1]) AS elev,
            trim(column0[begin_pos:end_pos-1]) AS report_start,
            trim(column0[end_pos:-1]) AS report_end 
        FROM str_positions_joined
    )
    SELECT 
        usaf_id || wban_num as station,
        row_number () over (partition by station) station_sk,
        usaf_id,
        wban_num, 
        station_name,
        fips_country,
        us_state,
        icao,
        ST_Point(lon::double, lat::double) AS geometry,
        case when elev = '' then 0.0 else elev::double end AS elev,
        MAKE_TIMESTAMPTZ(
            report_start[1:4]::bigint,
            report_start[5:6]::bigint,
            report_start[7:8]::bigint,
            0::bigint,
            0::bigint,
            0.0,
            'utc'
        ) AS report_start,
        MAKE_TIMESTAMPTZ(
            report_end[1:4]::bigint,
            report_end[5:6]::bigint,
            report_end[7:8]::bigint,
            0::bigint,
            0::bigint,
            0.0,
            'utc'
        ) AS report_end
    FROM raw_columns
    WHERE lat != '' AND lon != ''

    """
    return context.fetchdf(query)