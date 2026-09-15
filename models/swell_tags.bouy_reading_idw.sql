MODEL(
    name swell.bouy_reading_idw,
    kind INCREMENTAL_BY_TIME_RANGE (
        time_column timestamp_tz
    ),
    start '2000-01-01',
    allow_partials true
);

SET extension_directory = '/var/task';
load h3;
load spatial;

with
bouy_h3s_radii as (
    select h3_04, unnest(h3_grid_disk_distances_safe(h3_04, floor(60 / (h3_get_hexagon_edge_length_avg(4, 'km') * 2))::integer)[2]) as in_radius_h3_04
    from coast.buffered_h3
),
bouy_history_snap as (
    select station_id, last(geometry) as geometry, last(bouy_history.h3_04) as h3_04
    from ndbc_duck.bouy_history
    join bouy_h3s_radii on bouy_h3s_radii.in_radius_h3_04=bouy_history.h3_04
    group by station_id
),
in_radius_stations as (
    select bouy_h3s_radii.h3_04,
           bouy_history_snap.h3_04,
           bouy_history_snap.station_id,
           bouy_history_snap.geometry,
           st_distance_sphere(
            st_point(h3_cell_to_lng(bouy_h3s_radii.h3_04),
                     h3_cell_to_lat(bouy_h3s_radii.h3_04)),
            bouy_history_snap.geometry
           ) as dist
    from bouy_h3s_radii
    join bouy_history_snap on bouy_history_snap.h3_04=in_radius_h3_04
),
-- then for time period, get me 1 hour sliding windows for ever 30 minutes.
at_30mins as (
    select generate_series as timestamp_tz,
           generate_series - '30 minute'::interval as lower,
           generate_series + '30 minute'::interval as upper
    from (
        select * from generate_series(@start_dt, @end_dt, '60 minutes'::interval)
    )
),
-- go join that back with the in 60km away stations
in_radius_stations_at_30mins as (
    select h3_04, timestamp_tz, lower, upper, station_id, dist
    from in_radius_stations join at_30mins on true=true
),
-- for each h3 cell, 30 minute interval pair, join for each in radius station reading that's in an hour of the timestamp_tz.
-- get the inverse distance weight reading_mm using the space-time dist.
in_radius_measurements as (
    select case when ndbc_duck.standard_measurements.wave_height == 99.0 then null else ndbc_duck.standard_measurements.wave_height end as wave_height,
           case when ndbc_duck.standard_measurements.average_wave_period == 99.0 then null else ndbc_duck.standard_measurements.average_wave_period end as average_wave_period,
           case when ndbc_duck.standard_measurements.measured_wave_direction == 999.0 then null else ndbc_duck.standard_measurements.measured_wave_direction end as measured_wave_direction,
           case when ndbc_duck.standard_measurements.tide == 99.0 then null else ndbc_duck.standard_measurements.tide end as tide,
           case when ndbc_duck.standard_measurements.wind_direction == 999.0 then null else ndbc_duck.standard_measurements.wind_direction end as wind_direction,
           case when ndbc_duck.standard_measurements.wind_speed == 99.0 then null else ndbc_duck.standard_measurements.wind_speed end as wind_speed,
           in_radius_stations_at_30mins.h3_04,
           in_radius_stations_at_30mins.timestamp_tz,
           pow(sqrt(
            pow(in_radius_stations_at_30mins.dist,2)+
            pow(abs(date_diff('minutes', in_radius_stations_at_30mins.timestamp_tz,ndbc_duck.standard_measurements.timestamp_tz)), 2)
           ),2) as idw
    from in_radius_stations_at_30mins
    join ndbc_duck.standard_measurements on ndbc_duck.standard_measurements.station_id=in_radius_stations_at_30mins.station_id and
                                            ndbc_duck.standard_measurements.timestamp_tz between lower and upper
)
-- love me a group by to get the estimated value at each cell
select distinct h3_04,
       timestamp_tz,
       round(sum(idw*wave_height)/sum(idw),2) as idw_wave_height,
       round(sum(idw*average_wave_period)/sum(idw),2) as idw_average_wave_period,
       round(sum(idw*measured_wave_direction)/sum(idw),2) as idw_measured_wave_direction,
       round(sum(idw*wind_direction)/sum(idw),2) as idw_wind_direction,
       round(sum(idw*wind_speed)/sum(idw),2) as idw_wind_speed,
       round(sum(idw*tide)/sum(idw),2) as idw_tide
from in_radius_measurements group by h3_04, timestamp_tz
order by h3_04, timestamp_tz