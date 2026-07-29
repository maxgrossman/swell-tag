  
AUDIT (
  name assert_distinct_on_station_time
);
-- only allow 1 per station_id + timestamp_tz
SELECT station_id, timestamp_tz, COUNT(*)
FROM @this_model
GROUP BY station_id, timestamp_tz
HAVING count(*) > 1