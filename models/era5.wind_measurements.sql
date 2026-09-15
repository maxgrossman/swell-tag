MODEL(
    name era5_duck.wind,
    kind INCREMENTAL_BY_TIME_RANGE (
        time_column timestamp_tz
    ),
    start '2000-01-01',
    columns (
        h3_04 uint64,
        geometry geometry,
        wind_speed_ms double,
        wind_dir double,
        timestamp_tz timestamptz
    )
);

SET extension_directory = '/var/task';
LOAD httpfs;
LOAD spatial;
LOAD h3;

set variable era5_10u_archive_list = (
    select list(parquet_path) from (
        select parquet_path from era5_duck.archive
        where start_timestamp_tz <= @end_dt and
              end_timestamp_tz >= @start_dt and
              parquet_path ~* '10u'
    )
);

set variable era5_10v_archive_list = (
    select list(parquet_path) from (
        select parquet_path from era5_duck.archive
        where start_timestamp_tz <= @end_dt and
              end_timestamp_tz >= @start_dt and
              parquet_path ~* '10v'
    )
);

WITH
v_era5 as (
    SELECT h3_cell as h3_04, longitude, latitude, VAR_10V, utc_date, utc_date::varchar as utc_str from read_parquet(getvariable('era5_10v_archive_list'), union_by_name=true)
),
u_era5 as (
    SELECT h3_cell as h3_04, longitude, latitude, VAR_10U, utc_date, utc_date::varchar as utc_str from read_parquet(getvariable('era5_10u_archive_list'), union_by_name=true)
),
-- since h3 04 will include more than 1 era 5 reading, gotta avg the values.
-- only thing don't love here is wind at coast != wind inland.
-- size 4 is big enough to get some inland wind in same cell someone at coast would be in.
-- evaluated smaller cell. maybe that and a more agressive (smaller) clipping is the way.
-- can always get the averaging part right and change the coastal indexes later on!
uv_era5_joined as (
    SELECT u_era5.h3_04, u_era5.utc_date,
           last(u_era5.utc_str) as utc_str,
           last(u_era5.longitude) as longitude, last(u_era5.latitude) as latitude, avg(VAR_10V) as avg_10v, avg(VAR_10U) as avg_10u
    FROM v_era5 JOIN u_era5 ON u_era5.h3_04 = v_era5.h3_04 AND u_era5.utc_date = v_era5.utc_date
    GROUP BY u_era5.h3_04, u_era5.utc_date
)
SELECT h3_04 as h3_04,
       ST_Point(longitude, latitude) as geometry,
       sqrt(pow(avg_10v,2) + pow(avg_10u,2)) as wind_speed_ms,
       mod(degrees(atan2(-avg_10u, -avg_10v)) + 360, 360) as wind_dir,
       make_timestamptz(utc_str[1:4]::bigint,utc_str[5:6]::bigint,
                        utc_str[7:8]::bigint,utc_str[9:10]::bigint,
                        0::bigint,0.0::double,'utc') as timestamp_tz
FROM uv_era5_joined
order by h3_04 asc, timestamp_tz asc