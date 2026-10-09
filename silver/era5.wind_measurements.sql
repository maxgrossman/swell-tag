LOAD httpfs;
LOAD spatial;
LOAD h3;

create schema if not exists era5;
create table if not exists era5.wind (
    h3_04 uint64,
    geometry geometry,
    wind_speed_ms double,
    wind_dir double,
    timestamp_tz timestamptz
);

WITH
v_era5 as (
    SELECT h3_cell as h3_04, longitude, latitude, wind_dim_val as VAR_10V, utc_date, utc_date::varchar as utc_str
    FROM read_parquet('s3://swell-tags-us-west-2/bronze/raw/era5/utc_month=*/wind_dim=VAR_10V/*.parquet', hive_partitioning=true)
    WHERE utc_date BETWEEN $start_dt and $end_dt
),
u_era5 as (
    SELECT h3_cell as h3_04, longitude, latitude, wind_dim_val as VAR_10U, utc_date, utc_date::varchar as utc_str
    FROM read_parquet('s3://swell-tags-us-west-2/bronze/raw/era5/utc_month=*/wind_dim=VAR_10U/*.parquet', hive_partitioning=true)
    WHERE utc_date BETWEEN $start_dt and $end_dt
),
-- since h3 04 will include more than 1 era 5 reading, gotta avg the values.
-- only thing don't love here is wind at coast != wind inland.
-- size 4 is big enough to get some inland wind in same cell someone at coast would be in.
-- evaluated smaller cell. maybe that and a more agressive (smaller) clipping is the way.
-- can always get the averaging part right and change the coastal indexes later on!
uv_era5_joined as (
    SELECT u_era5.h3_04, u_era5.utc_date as timestamp_tz,
           last(u_era5.utc_str) as utc_str,
           last(u_era5.utc_date) as utc_date,
           last(u_era5.longitude) as longitude, last(u_era5.latitude) as latitude, avg(VAR_10V) as avg_10v, avg(VAR_10U) as avg_10u
    FROM v_era5 JOIN u_era5 ON u_era5.h3_04 = v_era5.h3_04 AND u_era5.utc_date = v_era5.utc_date
    GROUP BY u_era5.h3_04, u_era5.utc_date
)
INSERT INTO era5.wind
SELECT h3_04 as h3_04,
       ST_Point(longitude, latitude) as geometry,
       sqrt(pow(avg_10v,2) + pow(avg_10u,2)) as wind_speed_ms,
       mod(degrees(atan2(-avg_10u, -avg_10v)) + 360, 360) as wind_dir,
       utc_date
FROM uv_era5_joined s_wind
ANTI JOIN era5.wind t_wind ON s_wind.h3_04 = t_wind.h3_04 and s_wind.timestamp_tz=t_wind.timestamp_tz
ORDER BY h3_04 ASC, timestamp_tz ASC