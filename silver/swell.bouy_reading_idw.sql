load h3;
load spatial;

create schema if not exists swell;
create table if not exists swell.bouy_reading_idw (
    h3_04 uint64,
    timestamp_tz timestamptz,
    idw_wave_height double,
    idw_average_wave_period double,
    idw_measured_wave_direction double,
    idw_wind_direction double,
    idw_wind_speed double,
    idw_tide double
);

with
coast_grids_grid_disks_list as (
    select h3_04, h3_grid_disk_distances_safe(h3_04, 2) as in_radius_h3_04
    from (select distinct h3_04 from coast.buffered_h3s)
),
coast_grids_grid_disks_flat as (
    select h3_04, list_concat(in_radius_h3_04[2], in_radius_h3_04[3], [h3_04]) as in_radius_h3_04
    from coast_grids_grid_disks_list
),
coast_grids_grid_disks as (
    select h3_04, unnest(in_radius_h3_04) as in_radius_h3_04
    from coast_grids_grid_disks_flat
),
in_time_stations as (
    select distinct station_id, h3_04, geometry
    from ndbc.standard_measurements
    where timestamp_tz between $start_dt and $end_dt
),
in_radius_stations as (
    select coast_grids_grid_disks.h3_04,
           coast_grids_grid_disks.in_radius_h3_04,
           in_time_stations.station_id,
           st_distance_sphere(
                st_point(h3_cell_to_lng(coast_grids_grid_disks.h3_04),
                        h3_cell_to_lat(coast_grids_grid_disks.h3_04)),
                in_time_stations.geometry
           ) as dist
    from coast_grids_grid_disks
    join in_time_stations on in_time_stations.h3_04=in_radius_h3_04
),
-- get the average for each hour where inputs to that average are 30 minutes before and after the top of the hour
station_measurements_at_hour as (
   select station_id,
          case when minute(time_bucket(interval '30 minutes', timestamp_tz)) = 30
               then time_bucket(interval '30 minutes', timestamp_tz) + '30 minutes'::interval
               else time_bucket(interval '30 minutes', timestamp_tz) end as timestamp_tz, -- rounds these to the hour
        avg(case when wave_height == 99.0 then null else wave_height end) as wave_height,
        avg(case when average_wave_period == 99.0 then null else average_wave_period end) as average_wave_period,
        avg(case when measured_wave_direction == 999 then null else measured_wave_direction end) as measured_wave_direction,
        avg(case when tide == 99.0 then null else tide end) as tide,
        avg(case when wind_direction == 999 then null else wind_direction end) as wind_direction,
        avg(case when wind_speed == 99.0 then null else wind_speed end) as wind_speed
    from ndbc.standard_measurements
    where ndbc.standard_measurements.timestamp_tz between $start_dt and $end_dt
    group by station_id, case when minute(time_bucket(interval '30 minutes', timestamp_tz)) = 30
               then time_bucket(interval '30 minutes', timestamp_tz) + '30 minutes'::interval
               else time_bucket(interval '30 minutes', timestamp_tz) end
    order by station_id, case when minute(time_bucket(interval '30 minutes', timestamp_tz)) = 30
               then time_bucket(interval '30 minutes', timestamp_tz) + '30 minutes'::interval
               else time_bucket(interval '30 minutes', timestamp_tz) end
),
-- now go join those values back each of the 'in radius of station bouy' h3s...
-- one thing that could optimize this prolly would be to not do the pow on each row. but tbh still fast enough.
in_radius_measurements as (
    select
           in_radius_stations.h3_04 as h3_04,
           dist,
           case when dist = 0 then null else 1.0 / pow(in_radius_stations.dist, 2) end as idw,
           station_measurements_at_hour.*
    from station_measurements_at_hour
    join in_radius_stations on station_measurements_at_hour.station_id=in_radius_stations.station_id
    where station_measurements_at_hour.wave_height is not null and station_measurements_at_hour.measured_wave_direction is not null
),
-- last, interpolate the idw for each cell...
idw_readings as (
    select h3_04, timestamp_tz,
        round(coalesce(
            max(CASE WHEN dist = 0 THEN wave_height END),
            sum(idw*wave_height)/sum(idw)
        ),2) AS idw_wave_height,
        round(coalesce(
            max(CASE WHEN dist = 0 THEN average_wave_period END),
            sum(idw*average_wave_period)/sum(idw)
        ),2) AS idw_average_wave_period,
        round(coalesce(
            max(CASE WHEN dist = 0 THEN measured_wave_direction END),
            sum(idw*measured_wave_direction)/sum(idw)
        ),2) AS idw_measured_wave_direction,
        round(coalesce(
            max(CASE WHEN dist = 0 THEN wind_direction END),
            sum(idw*wind_direction)/sum(idw)
        ),2) AS idw_wind_direction,
        round(coalesce(
            max(CASE WHEN dist = 0 THEN wind_speed END),
            sum(idw*wind_speed)/sum(idw)
        ),2) AS idw_wind_speed,
        round(coalesce(
            max(CASE WHEN dist = 0 THEN tide END),
            sum(idw*tide)/sum(idw)
        ),2) AS idw_tide,
    from in_radius_measurements
    group by h3_04, timestamp_tz
    order by h3_04, timestamp_tz
)
insert into swell.bouy_reading_idw
select * from idw_readings s_readings