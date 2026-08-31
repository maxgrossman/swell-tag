BASELINE_MODELS = [
    'coast.buffered_h3',
    'coast.lines',
    'coast.cells_lookup',
    'ndbc_duck.archive',
    'ndbc_duck.archive_realtime',
    'ndbc_duck.bouy_history',
    'ushlc.archive',
    'ushlc.stations',
    'era5_duck.archive',
]

RAW_MODELS = [
    'ndbc_duck.raw_measurements',
    'ndbc_duck.raw_measurements_realtime',
    'ushlc.station_measurements',
    'era5_duck.wind'
]

INTERPOLATED_MODELS = [
    'swell_tags.tide_idw',
    'swell_tags.bouy_reading_idw'
]

MERGED_MODELS = [
    'ndbc_duck.standard_measurements'
]

BACKFILLABLE_MODELS = RAW_MODELS + INTERPOLATED_MODELS + MERGED_MODELS