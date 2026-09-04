import os

SQLMESH_CONFIG_PATH = os.getenv("SQLMESH_CONFIG_PATH", ".")
SQLMESH_GATEWAY = os.getenv("SQLMESH_GATEWAY", "duckdb_s3")
SQLMESH_PATH = os.getenv("SQLMESH_PATH", "sqlmesh")
SQLMESH_LOG_DIR = os.getenv("SQLMESH_LOG_DIR", "./logs")
SQLMESH_DEBUG = os.getenv("SQLMESH_DEBUG", "false") == "true"
SQLMESH_COMMAND = [SQLMESH_PATH, '--paths', SQLMESH_CONFIG_PATH,'--log-file-dir', SQLMESH_LOG_DIR, '--log-to-stdout']

if SQLMESH_DEBUG: SQLMESH_COMMAND.append("--debug")

BASELINE_MODELS = [
    "coast.buffered_h3",
    "coast.lines",
    "coast.cells_lookup",
    "ndbc_duck.archive",
    "ndbc_duck.archive_realtime",
    "ndbc_duck.bouy_history",
    "ushlc.archive",
    "ushlc.stations",
    "era5_duck.archive",
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
