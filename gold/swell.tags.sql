load spatial;
load h3;
load spatial;

create schema if not exists swell;
create table if not exists swell.tags (
    timestamp_tz timestamptz,
    h3_04 uint64,
    swell_tag double[]
);

with
filtered_swell as (
    select h3_04,
           timestamp_tz,
           idw_wave_height,
           idw_average_wave_period,
           idw_wind_speed,
           idw_wind_direction,
           idw_tide,
           idw_measured_wave_direction
    from swell.bouy_reading_idw
    where timestamp_tz between $start_dt and $end_dt
),
swell_h3_04s as (select distinct h3_04 from filtered_swell),
filtered_wind as (
    select swell_h3_04s.h3_04, timestamp_tz,
           wind_speed_ms, wind_dir
    from swell_h3_04s
    left join era5.wind on era5.wind.h3_04=swell_h3_04s.h3_04
    where timestamp_tz between $start_dt and $end_dt
),
filtered_tide as (
    select swell_h3_04s.h3_04, timestamp_tz, idw_mm
    from swell_h3_04s
    left join swell.tide_idw on swell.tide_idw.h3_04=swell_h3_04s.h3_04
    where timestamp_tz between $start_dt and $end_dt
),
swell_tag_data as (
    select filtered_swell.h3_04, filtered_swell.timestamp_tz,
           idw_wave_height,
           idw_average_wave_period,
           idw_measured_wave_direction,
           coalesce(wind_speed_ms,idw_wind_speed) as wind_speed,
           coalesce(wind_dir,idw_wind_direction) as wind_direction,
           coalesce(round(idw_mm/1000.0,2), idw_tide) as tide_meters
    from filtered_swell
    left join filtered_tide on filtered_swell.h3_04=filtered_tide.h3_04 and
                               filtered_swell.timestamp_tz=filtered_tide.timestamp_tz
    left join filtered_wind on filtered_swell.h3_04=filtered_wind.h3_04 and
                               filtered_swell.timestamp_tz=filtered_wind.timestamp_tz
    where filtered_swell.timestamp_tz between $start_dt and $end_dt
),
swell_tags as (
    select
        timestamp_tz,
        h3_04,
        [
            h3_04::double,
            idw_wave_height::double,
            idw_average_wave_period::double,
            idw_measured_wave_direction::double,
            tide_meters::double,
            round(wind_speed::double,2),
            round(wind_direction::double,2)
        ] as swell_tag
    from swell_tag_data
    where idw_wave_height is not null and
          idw_average_wave_period is not null and
          idw_measured_wave_direction is not null and
          wind_speed is not null and
          wind_direction is not null and
          tide_meters is not null
    order by h3_04, timestamp_tz
)
insert into swell.tags
select * from swell_tags s_tags
