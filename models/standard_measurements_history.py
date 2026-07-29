from sqlmesh import model
from sqlmesh.core.model.kind import ModelKindName
from datetime import timedelta

MODEL_NAME="ndbc_duck.standard_measurements"
INTERVAL_NAME = 'five_minute'
LOOKBACK = int((48*60)/5) #2 days worth of late data allowed

@model(
    name=MODEL_NAME,
    kind={
        "name": ModelKindName.INCREMENTAL_BY_TIME_RANGE,
        "time_column": "timestamp_tz"
    }, 
    depends_on=[
        "ndbc_duck.raw_measurements", 
        "ndbc_duck.raw_measurements_realtime", 
        "ndbc_duck.raw_measurements_latest_obs", 
        "ndbc_duck.bouy_history"
    ],
    grain=['station_id','timestamp_tz'],
    start='2000-01-01',
    columns={
        "station_id": "varchar",
        "timestamp_tz": "timestamptz",
        "station_sk": "int",
        "geometry": "blob",
        "quadkey": "varchar",
        "wind_direction": "int",
        "wind_speed": "double",
        "wind_gust": "double",
        "wave_height": "double",
        "dominant_wave_period": "double",
        "average_wave_period": "double",
        "measured_wave_direction": "int",
        "sea_level_pressure": "double",
        "air_temp": "double",
        "water_temp": "double",
        "dew_point_temp": "double",
        "visibility": "double",
        "tide": "double"
    }
)
def execute(context, start, end, **kwargs):
    lookback_seconds = LOOKBACK * 60 * 5
    start_fmt = (start-timedelta(seconds=lookback_seconds)).isoformat()
    start_fmt = start.isoformat()
    end_fmt = end.isoformat()
    query = f"""
    INSTALL spatial; LOAD spatial;
    WITH 
    -- FIRST GET ALL THE RAW OBSERVATIONS ACROSS THE THREE TABLES THAT ARE IN THE TIME WINDOW
    raw_history AS 
        (SELECT ndbc_duck.raw_measurements.station_id, 
                ndbc_duck.raw_measurements.timestamp_tz, 
                ndbc_duck.raw_measurements.line
        FROM ndbc_duck.raw_measurements
        LEFT JOIN ndbc_duck.standard_measurements
        ON ndbc_duck.standard_measurements.station_id = ndbc_duck.raw_measurements.station_id AND
            ndbc_duck.standard_measurements.timestamp_tz = ndbc_duck.raw_measurements.timestamp_tz
        WHERE ndbc_duck.standard_measurements.station_id IS NULL
        AND ndbc_duck.raw_measurements.timestamp_tz BETWEEN '{start_fmt}'::timestamptz AND
                                                            '{end_fmt}'::timestamptz),
    raw_realtime AS 
        (SELECT ndbc_duck.raw_measurements_realtime.station_id, 
                ndbc_duck.raw_measurements_realtime.timestamp_tz, 
                ndbc_duck.raw_measurements_realtime.line
        FROM ndbc_duck.raw_measurements_realtime
        LEFT JOIN ndbc_duck.standard_measurements
        ON ndbc_duck.standard_measurements.station_id = ndbc_duck.raw_measurements_realtime.station_id AND
            ndbc_duck.standard_measurements.timestamp_tz = ndbc_duck.raw_measurements_realtime.timestamp_tz
        WHERE ndbc_duck.standard_measurements.station_id IS NULL
        AND ndbc_duck.raw_measurements_realtime.timestamp_tz BETWEEN '{start_fmt}'::timestamptz AND
                                                            '{end_fmt}'::timestamptz),
    raw_latest_obs AS
        (SELECT ndbc_duck.raw_measurements_latest_obs.station_id, 
                ndbc_duck.raw_measurements_latest_obs.timestamp_tz, 
                ndbc_duck.raw_measurements_latest_obs.line[4:]
        FROM ndbc_duck.raw_measurements_latest_obs
        LEFT JOIN ndbc_duck.standard_measurements
        ON ndbc_duck.standard_measurements.station_id = ndbc_duck.raw_measurements_latest_obs.station_id AND
            ndbc_duck.standard_measurements.timestamp_tz = ndbc_duck.raw_measurements_latest_obs.timestamp_tz
        WHERE ndbc_duck.standard_measurements.station_id IS NULL
        AND ndbc_duck.raw_measurements_latest_obs.timestamp_tz BETWEEN '{start_fmt}'::timestamptz AND
                                                            '{end_fmt}'::timestamptz),
    all_raw_obs AS 
        (SELECT station_id, timestamp_tz, line from raw_history
        UNION ALL
        SELECT station_id, timestamp_tz, line from raw_realtime
        UNION ALL
        SELECT station_id, timestamp_tz, line from raw_realtime),
    -- THEN HANDLE ANY DUPLICATES ACROSS TABLES WITH A DISTINCT ON, PLUS TIE I TTO THE BOUY TABLE
    new_raw_obs as  
        (SELECT DISTINCT ON (station_id, timestamp_tz) 
            all_raw_obs.station_id, timestamp_tz, line, bouy_history.station_sk, bouy_history.geometry
        FROM all_raw_obs
        JOIN ndbc_duck.bouy_history
        ON timestamp_tz <= coalesce(ndbc_duck.bouy_history.end_time, timestamp_tz)
        AND all_raw_obs.station_id = ndbc_duck.bouy_history.station_id
        ORDER BY station_id, timestamp_tz ASC)
    --CREATE FINAL, TRANSFORMED/QUERIABLE VIEW OF THE RAW DATA.
    SELECT 
        new_raw_obs.station_id,
        new_raw_obs.timestamp_tz,
        new_raw_obs.station_sk,
        new_raw_obs.geometry,
        st_quadkey(st_geomfromwkb(new_raw_obs.geometry), 8) as quadkey,
        coalesce(try_cast(new_raw_obs.line[6] as int), 999)::int as wind_direction,
        coalesce(try_cast(new_raw_obs.line[7] as double),999.9)::double as wind_speed,
        coalesce(try_cast(new_raw_obs.line[8] as double),999.9)::double as wind_gust,
        coalesce(try_cast(new_raw_obs.line[9] as double),999.9)::double as wave_height,
        coalesce(try_cast(new_raw_obs.line[10] as double),999.9)::double as dominant_wave_period,
        coalesce(try_cast(new_raw_obs.line[11] as double),999.9)::double average_wave_period,
        coalesce(try_cast(new_raw_obs.line[12] as double),999.9)::double as measured_wave_direction,
        coalesce(try_cast(new_raw_obs.line[13] as double),999.9)::double as sea_level_pressure,
        coalesce(try_cast(new_raw_obs.line[14] as double),999.9)::double as air_temp,
        coalesce(try_cast(new_raw_obs.line[15] as double),999.9)::double as water_temp,
        coalesce(try_cast(new_raw_obs.line[16] as double),999.9)::double as dew_point_temp,
        coalesce(try_cast(new_raw_obs.line[17] as double),999.9)::double as visibility,
        coalesce(try_cast(new_raw_obs.line[18] as double),999.9)::double as tide
    FROM new_raw_obs
    WHERE timestamp_tz BETWEEN '{start_fmt}'::timestamptz AND '{end_fmt}'::timestamptz
    """

    dataframe = context.fetchdf(query) 
    return dataframe