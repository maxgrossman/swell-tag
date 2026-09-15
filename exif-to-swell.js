const ExifReader = require('exifreader');
const duckdb = require('@duckdb/node-api');


const query = (lng, lat, isotimestamp) => {

    const formatted_q = `
    INSTALL spatial; LOAD spatial;
    INSTALL VSS; LOAD VSS;
    INSTALL h3 FROM community; LOAD h3;
    -- FIRST, GO FIND BOUY READINGS ON THE SAME DAY.
    -- THEN FOR THOSE READINGS, GET ME THE CLOSEST IN TIME AND SPACE.
    WITH
    matching_swell_tags as (
        SELECT timestamp_tz, h3_04, swell_tag, date_diff('seconds', timestamp_tz, getvariable('search_timestamp_tz')) as time_dist
        FROM swell.tags
        WHERE h3_04 = h3_latlng_to_cell(${lat},${lng}, 4) AND timestamp_tz BETWEEN '${isotimestamp}'::timestamptz-'30 minutes'::interval
                                                                            AND '${isotimestamp}'::timestamptz+'30 minutes'::interval
        ORDER BY time_dist asc
    ),
    closest_matching_swell_tag as (
        SELECT timestamp_tz, h3_04, swell_tag
        FROM matching_swell_tags limit 1
    )
    select swell.tags.timestamp_tz, 
           swell.tags.swell_tag as nearby_swell_tags, 
           closest_matching_swell_tag.swell_tag as matching_swell_tag,
           round(array_distance(closest_matching_swell_tag.swell_tag[2:]::double[6], swell.tags.swell_tag[2:]::double[6]),2) as l2_dist
    from swell.tags 
    join closest_matching_swell_tag on true=true
    where swell.tags.swell_tag[4] is not null and array_distance(closest_matching_swell_tag.swell_tag[2:]::double[6], swell.tags.swell_tag[2:]::double[6]) < 10 -- very scientific
    order by swell.tags.h3_04, swell.tags.timestamp_tz asc;
    `
    return formatted_q
}

function printResults(results) {
    console.log(results[0].matching_swell_tag.items)
    results.forEach(result => {
        console.log(result.timestamp_tz + ' ' + result.nearby_swell_tags.items + ' l2_dist = ' + result.l2_dist)
    })
}

async function main() {
    const args = process.argv.slice(2)
    if (args.length == 0) {
        throw Error("No file given")
    }

    const file = args[0]
    const db = args[1] || 'ndbc.db'
    const tags = await ExifReader.load(file)
    const lat = tags.GPSLatitude.description * (tags.GPSLatitudeRef.value[0] == 'S' ? -1 : 1)
    const lon = tags.GPSLongitude.description * (tags.GPSLongitudeRef.value[0] == 'W' ? -1 : 1)
    const datetime = tags.DateTimeDigitized.value[0].split(' ')
    datetime[0] = datetime[0].replaceAll(':','-')
    const tz_date = new Date(Date.parse(datetime[0] + 'T' + datetime[1] + tags.OffsetTime.description)).toISOString()

    const instance = await duckdb.DuckDBInstance.create(db, {threads: '4'});
    const prepared_query = query(lon, lat, tz_date)
    const connection = await instance.connect();
    const result = await connection.runAndReadAll(prepared_query)
    printResults(result.getRowObjects())
}

main()