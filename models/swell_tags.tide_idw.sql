MODEL(
    name swell.tide_idw,
    kind INCREMENTAL_BY_TIME_RANGE (
        time_column timestamp_tz
    ),
    start '2000-01-01'
);

SET extension_directory = '/var/task';
load h3;
load spatial;
-- look for bouys in 60km radius of a h3 cells. taht feels reasonable, maybe not tho!
with
bouy_h3s_radii_list as (
    select h3_04, h3_grid_disk_distances_safe(h3_04, floor(60 / (h3_get_hexagon_edge_length_avg(4, 'km') * 2))::integer) as in_radius_h3_04
    from coast.buffered_h3
),
bouy_h3s_radii as (
    select h3_04, unnest(list_concat(in_radius_h3_04[1], in_radius_h3_04[2])) as in_radius_h3_04
    from bouy_h3s_radii_list
),
in_radius_stations as (
    select bouy_h3s_radii.h3_04, ushlc.stations.uh_id, ushlc.stations.version,
           st_distance_sphere(
            st_point(h3_cell_to_lng(bouy_h3s_radii.h3_04),
                     h3_cell_to_lat(bouy_h3s_radii.h3_04)),
            ushlc.stations.geometry
           ) as dist
    from bouy_h3s_radii
    join ushlc.stations on ushlc.stations.h3_04=in_radius_h3_04
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
    select h3_04, timestamp_tz, lower, upper, uh_id, version, dist
    from in_radius_stations join at_30mins on true=true
),
-- for each h3 cell, 30 minute interval pair, join for each in radius station reading that's in an hour of the timestamp_tz.
-- get the inverse distance weight reading_mm using the space-time dist.
in_radius_measurements as (
    select ushlc.station_measurements.reading_mm,
           ushlc.station_measurements.timestamp_tz,
           in_radius_stations_at_30mins.h3_04,
           in_radius_stations_at_30mins.timestamp_tz,
           ushlc.station_measurements.reading_mm,
           pow(sqrt(
            pow(in_radius_stations_at_30mins.dist,2)+
            pow(abs(date_diff('minutes', in_radius_stations_at_30mins.timestamp_tz,ushlc.station_measurements.timestamp_tz)), 2)
           ),2) as idw
    from in_radius_stations_at_30mins
    join ushlc.station_measurements on ushlc.station_measurements.uh_id=in_radius_stations_at_30mins.uh_id and
                                       ushlc.station_measurements.version=in_radius_stations_at_30mins.version
    where ushlc.station_measurements.timestamp_tz between lower and upper
)
-- love me a group by to get the estimated value at each cell
select h3_04, timestamp_tz, round(sum(idw*reading_mm)/sum(idw),2) as idw_mm
from in_radius_measurements group by h3_04, timestamp_tz
order by h3_04, timestamp_tz