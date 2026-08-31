MODEL(
    name coast.cells_lookup,
    kind full,
    columns (
        lats double[],
        lons double[]
    )
);

with 
coastline_shape_proj as 
    (SELECT 'EPSG:' || layers[1].geometry_fields[1].crs.auth_code as epsg
    FROM st_read_meta('/vsizip//vsicurl/https://www2.census.gov/geo/tiger/TIGER2023/COASTLINE/tl_2023_us_coastline.zip')),
coastlines as 
    (SELECT ST_Transform(geom, (select epsg from coastline_shape_proj), 'epsg:4326') as geom 
    FROM st_read('/vsizip//vsicurl/https://www2.census.gov/geo/tiger/TIGER2023/COASTLINE/tl_2023_us_coastline.zip')),
coastline_cells as 
    (SELECT h3_polygon_wkt_to_cells(st_aswkt(st_buffer(geom, .6)), 4) as h3_04
        FROM coastlines),
coastal_h3s as 
    (SELECT DISTINCT unnested_h3_04 as h3_04,
                        st_geomfromwkb(h3_cell_to_boundary_wkb(unnested_h3_04)) as geom 
    FROM coastline_cells, unnest(h3_uncompact_cells(h3_04,4)) as t(unnested_h3_04))
-- then, take the series of era5 lat lons (the .25 degree cells)
-- and left join so we only keep the ones that are within our
-- coastal cell h3s. probably have my dggs brain on and no reason could not just do a reg spatial join on this...
-- but same output either way.
select 
    array_agg(lat) as lats,
    array_agg(generate_series/100) as lons
from generate_series(-18000, 18000, 25)
join (
    select generate_series/100 as lat 
    from generate_series(-9000,9000,25)
)
on true=true
join coastal_h3s on coastal_h3s.h3_04=h3_latlng_to_cell(lat,generate_series/100,4)