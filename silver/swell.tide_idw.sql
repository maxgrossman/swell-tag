load h3;
load spatial;

create schema if not exists swell;

create table if not exists swell.tide_idw (
    h3_04 uint64,
    timestamp_tz timestamptz,
    idw_mm double
);

with
-- do a grid disk around each h3 cell roughly 45km.
-- idea is we will only do IDW when there is a bouy we query later
-- that is within that query radius
coast_grids_grid_disks_list as (
    select h3_04, h3_grid_disk_distances_safe(h3_04, 3) as in_radius_h3_04
    from (
      -- very fun thing to not forget that buffering coastlines that are in the same
      -- h3 index will mean there are m
      select distinct h3_04 from coast.buffered_h3s
    )
),
coast_grids_grid_disks_flat as (
    select h3_04, list_concat([h3_04],in_radius_h3_04[2], in_radius_h3_04[3]) as in_radius_h3_04
    from coast_grids_grid_disks_list
),
coast_grids_grid_disks as (
    select h3_04, unnest(in_radius_h3_04) as in_radius_h3_04
    from coast_grids_grid_disks_flat
),
-- finding the stations in radius, joining by asking 'what are the stations in that grid disk'
-- capture the spherical distance to do the idw later.
in_radius_stations as (
    select coast_grids_grid_disks.h3_04,
            in_radius_h3_04,
            (printf('%03d', ushlc.stations.uh_id) || ushlc.stations.version) as station_id,
            st_distance_sphere(
                st_point(h3_cell_to_lng(coast_grids_grid_disks.h3_04),
                        h3_cell_to_lat(coast_grids_grid_disks.h3_04)),
                ushlc.stations.geometry
            ) as dist
    from coast_grids_grid_disks
    join ushlc.stations on ushlc.stations.h3_04=in_radius_h3_04
),
-- then go and get the stations for the year, capturing the the distance
-- and original h3_04 that we looked for the bouys with
stations_of_the_year as (
    select
        ushlc.station_measurements.station_id,
        ushlc.station_measurements.timestamp_tz,
        ushlc.station_measurements.reading_mm,
        in_radius_stations.h3_04 as coast_buffered_h3_04,
        dist,
        case when dist = 0 then null else 1.0 / pow(dist, 2) end as idw,
    from ushlc.station_measurements
    join in_radius_stations on in_radius_stations.station_id=ushlc.station_measurements.station_id
    where timestamp_tz between $start_dt and $end_dt
    and reading_mm >= -2743 -- unscientific but saw some bogus tides that were -10 feet and afaik that's not happening
                            -- since alaska i think can get really crazy negative tides, for those looking at alaska surf
                            -- cut it off at ~ -9ft
),
idw_tide_readings as (
    select coast_buffered_h3_04 as h3_04,
           timestamp_tz,
           round(coalesce(
                max(CASE WHEN dist = 0 THEN reading_mm END),
                sum(idw*reading_mm)/sum(idw)
            ),2) AS idw_mm
    from stations_of_the_year
    group by coast_buffered_h3_04, timestamp_tz
    order by coast_buffered_h3_04, timestamp_tz
)
insert into swell.tide_idw
select * from idw_tide_readings s_readings
