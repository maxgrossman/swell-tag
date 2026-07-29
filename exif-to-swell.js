const ExifReader = require('exifreader');

async function main() {
    const args = process.argv.slice(2)
    if (args.length == 0) {
        throw Error("No file given")
    }

    const file = args[0]
    const db = args[1] || 'ndbc.db'
    const tags = await ExifReader.load(file)
    const lat = tags.GPSLatitude.description
    const lon = tags.GPSLongitude.description
    const datetime = tags.DateTimeDigitized.value[0].split(' ')
    datetime[0] = datetime[0].replaceAll(':','-')
    const tz_date = new Date(Date.parse(datetime[0] + 'T' + datetime[1] + tags.OffsetTime.description)).toISOString()
    console.log(tags.GPSLongitude)
    console.log(tags.GPSLatitude)

    // const instance = await DuckDBInstance.create(db, {threads: '4'});

    // const prepared = await connection.prepare('select $1, $2, $3 from ndbc_duck.standard_measurements');
    // prepared.bindVarchar(1, 'duck');
    // prepared.bindInteger(2, 42);
    // prepared.bindList(3, listValue([10, 11, 12]), LIST(INTEGER));
    // // OR, with type inference: prepared.bindList(3, [10, 11, 12]);
    // const result = await prepared.run();

}

main()