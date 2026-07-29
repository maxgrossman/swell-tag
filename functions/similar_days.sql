INSTALL spatial; LOAD spatial;
INSTALL VSS; LOAD VSS;
SET VARIABLE search_location = ST_Point(-117.251234,32.872092);
SET VARIABLE search_timestamp_tz = '2022-03-03T15:27:53+00:00'::timestamptz;
-- FIRST, GO FIND BOUY READINGS ON THE SAME DAY.
-- THEN FOR THOSE READINGS, GET ME THE CLOSEST IN TIME AND SPACE.
WITH 
bouy_candidates as 
    (SELECT station_id, timestamp_tz, quadkey, swell_tag, geometry
     FROM ndbc_duck.standard_measurements
     WHERE timestamp_tz
        BETWEEN 
            (getvariable('search_timestamp_tz')-'1 hour'::interval) 
        AND 
            getvariable('search_timestamp_tz')
     AND wave_height != 99.0),
bouy_candidates_distance as
    (SELECT 
        station_id, timestamp_tz, quadkey, swell_tag,
        ST_Distance_Sphere(getvariable('search_location'), st_geomfromwkb(geometry)) as space_dist,
        ABS(EPOCH(getvariable('search_timestamp_tz')-timestamp_tz)) as time_dist
     FROM bouy_candidates),
bouy_candidates_ranked as 
    (SELECT station_id, time_dist, quadkey, swell_tag, space_dist, timestamp_tz, time_dist,
            dense_rank() over (order by space_dist asc) as space_rank,
            dense_rank() over (partition by station_id order by time_dist asc) as time_rank,
        FROM bouy_candidates_distance), 
closest_bouy_candidate as (
    SELECT bouy_candidates_ranked.station_id,
            bouy_candidates_ranked.timestamp_tz,
            st_asgeojson(st_geomfromwkb(bouy_history.geometry)) as bouy_location,
            ndbc_duck.bouy_history.start_time,
            ndbc_duck.bouy_history.end_time,
            bouy_candidates_ranked.quadkey,
            bouy_candidates_ranked.swell_tag
    FROM bouy_candidates_ranked
    JOIN ndbc_duck.bouy_history on bouy_candidates_ranked.station_id = ndbc_duck.bouy_history.station_id
    AND timestamp_tz between start_time and coalesce(end_time, timestamp_tz)
    WHERE space_rank = 1 AND time_rank = 1
    ORDER by space_rank asc, time_rank asc
),
-- WITH THAT BOUY READING, GO AND LOOK AROUND FOR OTHER BOUYS THAT ARE IN THE SAME AREA.
-- RIGHT NOW CHEAPILY DO THAT BY MATCHING QUADKEYS
same_bouys as (
    select ndbc_duck.standard_measurements, closest_bouy_candidate.swell_tag
    from closest_bouy_candidate
    join ndbc_duck.standard_measurements on closest_bouy_candidate.quadkey=ndbc_duck.standard_measurements.quadkey
),
-- THEN USING THE SWELL TAG VECTOR, GET THE CLOSEST READINGS.
same_bouys_dist as (
    select 
        same_bouys.standard_measurements.station_id,
        same_bouys.standard_measurements.timestamp_tz,
        same_bouys.standard_measurements.swell_tag as hist_tag, 
        same_bouys.swell_tag as img_tag, 
        array_distance(same_bouys.standard_measurements.swell_tag, same_bouys.swell_tag) as euc_dist,
        dense_rank() over (order by euc_dist asc) as array_dist_rank
    from same_bouys
    where euc_dist < 1 -- there's some learning to be done on the best way to filter this...
)
-- then return those readings.
-- the cool thing if i had a db of timespace tagged photos would be then to return the photos on this day....
-- select date_trunc('day',timestamp_tz) as timestamp_tz_day, array_agg(hist_tag), array_agg(euc_dist), last(img_tag)
-- from same_bouys_dist
-- group by timestamp_tz_day
-- order by ANY_VALUE(euc_dist) asc
select * from closest_bouy_candidate;