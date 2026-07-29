install webbed from community;
load webbed;

copy (
    with urls as (
        select 'https://uhslc.soest.hawaii.edu/data/csv/rqds/atlantic/hourly/' || unnest(pre.a).href as archive_url, unnest(pre.a).href as href 
        from read_html('https://uhslc.soest.hawaii.edu/data/csv/rqds/atlantic/hourly/')
        union all
        select 'https://uhslc.soest.hawaii.edu/data/csv/rqds/indian/hourly/' || unnest(pre.a).href as archive_url, unnest(pre.a).href as href 
        from read_html('https://uhslc.soest.hawaii.edu/data/csv/rqds/indian/hourly/')
        union all
        select 'https://uhslc.soest.hawaii.edu/data/csv/rqds/pacific/hourly/' || unnest(pre.a).href as archive_url, unnest(pre.a).href  as href
        from read_html('https://uhslc.soest.hawaii.edu/data/csv/rqds/pacific/hourly/')
    )
    select archive_url[-8:-6] as uh_id, archive_url[-5] as version, archive_url 
    from urls
    where href != '../' 
) to 'data/ushlc.archive.csv'