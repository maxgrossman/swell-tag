INSTALL spatial; LOAD spatial;
INSTALL VSS; LOAD VSS;
SET VARIABLE search_location = ST_Point(-117.251234,32.872092);
SET VARIABLE search_timestamp_tz = '2022-03-03T15:27:53+00:00'::timestamptz;
-- FIRST, GO FIND BOUY READINGS ON THE SAME DAY.
-- THEN FOR THOSE READINGS, GET ME THE CLOSEST IN TIME AND SPACE.
WITH
swell_tag_candidates as (
    SELECT bouy_station_id, bouy_timestamp_tz, quadkey, swell_tag, st_geomfromwkb(bouy_geometry) as geometry
    FROM swell.tags
    WHERE bouy_timestamp_tz
        BETWEEN 
            (getvariable('search_timestamp_tz')-'1 hour'::interval) 
        AND 
            getvariable('search_timestamp_tz')
),
swell_tag_candidates_dist as (
    SELECT bouy_station_id, bouy_timestamp_tz, quadkey, swell_tag, 
           dense_rank() over (
                order by ST_Distance_Sphere(getvariable('search_location'), geometry),
                         ABS(EPOCH(getvariable('search_timestamp_tz')-bouy_timestamp_tz))
           ) as space_time_closest
    FROM swell_tag_candidates
),
closest_swell_tag_candidate as (
    SELECT swell_tag_candidates_dist.bouy_station_id,
           swell_tag_candidates_dist.bouy_timestamp_tz,
           st_asgeojson(st_geomfromwkb(bouy_history.geometry)) as bouy_location,
           ndbc_duck.bouy_history.start_time,
           ndbc_duck.bouy_history.end_time,
           swell_tag_candidates_dist.quadkey,
           swell_tag_candidates_dist.swell_tag
    FROM swell_tag_candidates_dist
    JOIN ndbc_duck.bouy_history on swell_tag_candidates_dist.bouy_station_id = ndbc_duck.bouy_history.station_id
    AND bouy_timestamp_tz between start_time and coalesce(end_time, bouy_timestamp_tz)
    WHERE space_time_closest = 1
),
-- -- WITH THAT BOUY READING, GO AND LOOK AROUND FOR OTHER BOUYS THAT ARE IN THE SAME AREA.
-- -- RIGHT NOW CHEAPILY DO THAT BY MATCHING QUADKEYS
same_bouys as (
    select swell.tags.bouy_station_id as oth_bouy_station_id,
           swell.tags.bouy_timestamp_tz as oth_bouy_timestamp_tz,
           swell.tags.swell_tag as oth_swell_tag,
           closest_swell_tag_candidate.bouy_station_id,
           closest_swell_tag_candidate.bouy_timestamp_tz,
           closest_swell_tag_candidate.swell_tag
    from closest_swell_tag_candidate
    join swell.tags on closest_swell_tag_candidate.quadkey=swell.tags.quadkey
),
-- THEN USING THE SWELL TAG VECTOR, GET THE CLOSEST READINGS.
select 
    same_bouys.bouy_station_id,
    same_bouys.oth_bouy_station_id,
    same_bouys.bouy_timestamp_tz,
    same_bouys.oth_bouy_timestamp_tz,
    same_bouys.oth_swell_tag as hist_tag, 
    same_bouys.swell_tag as img_tag, 
    round(array_distance(same_bouys.oth_swell_tag, same_bouys.swell_tag),3) as euc_dist
from same_bouys
where euc_dist < 1
order by oth_bouy_timestamp_tz asc

-- -- then return those readings.
-- -- the cool thing if i had a db of timespace tagged photos would be then to return the photos on this day....
-- -- select date_trunc('day',timestamp_tz) as timestamp_tz_day, array_agg(hist_tag), array_agg(euc_dist), last(img_tag)
-- -- from same_bouys_dist
-- -- group by timestamp_tz_day
-- -- order by ANY_VALUE(euc_dist) asc
-- select * from closest_swell_tag_candidate;