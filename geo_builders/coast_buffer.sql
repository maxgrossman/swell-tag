install h3 from community;
load h3;
load spatial;
copy (
    -- go read the census shapes, project them, buffer them and get me h3 cells at level 8
    with 
    -- basicaly just a phatter buffer around the exterior of the polygons you get from
    coastline_shape_proj as 
        (SELECT 'EPSG:' || layers[1].geometry_fields[1].crs.auth_code as epsg
        FROM st_read_meta('/vsizip//vsicurl/https://www2.census.gov/geo/tiger/TIGER2023/COASTLINE/tl_2023_us_coastline.zip')),
    coastlines as 
        (SELECT ST_Transform(geom, (select epsg from coastline_shape_proj), 'epsg:4326') as geom 
        FROM st_read('/vsizip//vsicurl/https://www2.census.gov/geo/tiger/TIGER2023/COASTLINE/tl_2023_us_coastline.zip')),
    coastline_cells as 
        (SELECT h3_polygon_wkt_to_cells(st_aswkt(st_buffer(geom, .6)),4) as h3_04
         FROM coastlines),
    coastal_h3s as 
        (SELECT DISTINCT unnested_h3_04 as h3_04,
                         st_geomfromwkb(h3_cell_to_boundary_wkb(unnested_h3_04)) as geom 
         FROM coastline_cells, unnest(h3_04) as t(unnested_h3_04))
    select st_buffer(st_simplify(st_union_agg(geom), .5),.5) from coastal_h3s 
) to 'data/coast_buffer.geojson' with (format gdal, driver 'geojson', srs 'epsg:4326');
