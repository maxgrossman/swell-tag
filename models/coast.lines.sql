MODEL(
    name coast.lines,
    kind full,
    columns (
        geom geometry
    )
);

load spatial;
-- go read the census shapes, project them, buffer them and get me h3 cells at level 8
with 
coastline_shape_proj as 
    (SELECT 'EPSG:' || layers[1].geometry_fields[1].crs.auth_code as epsg
    FROM st_read_meta('/vsizip//vsicurl/https://www2.census.gov/geo/tiger/TIGER2023/COASTLINE/tl_2023_us_coastline.zip'))
SELECT ST_Transform(geom, (select epsg from coastline_shape_proj), 'epsg:4326') as geom 
FROM st_read('/vsizip//vsicurl/https://www2.census.gov/geo/tiger/TIGER2023/COASTLINE/tl_2023_us_coastline.zip')