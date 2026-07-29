INSTALL crawler from community;
LOAD crawler;
INSTALL webbed from community;
LOAD webbed;

SET variable linkies = (
    select list(links) from (
        select 'https://www.ngdc.noaa.gov/thredds/catalog/nos_coops/wl_1min/processed/' || Dataset || '/catalog.html' as links 
        from read_html('https://www.ngdc.noaa.gov/thredds/catalog/nos_coops/wl_1min/processed/sitemap.html', 'table', 1) offset 1
    )
);

COPY (
    WITH 
    table_rows as 
        (select unnest(tr) as rowz from read_html(getvariable('linkies'), root_element='table')), 
    table_tds as 
        (select unnest(rowz.td) as tds from table_rows where rowz.td is not null),
    archive_links as 
        (select 'https://www.ngdc.noaa.gov/thredds/fileServer/nos_coops/wl_1min/processed/' || str_split(tds.a.code, '_')[1] || '/' || tds.a.code as link
        from table_tds where tds.a.code is not null and tds.a.code like '%qc.csv.gz%')
    select link, 
        strptime(regexp_extract(link, '\d{8}to\d{8}')[:8], '%Y%m%d') as start_time,
        strptime(regexp_extract(link, '\d{8}to\d{8}')[-8:], '%Y%m%d') as end_time 
    from archive_links
) TO 'data/coops.archive.csv'