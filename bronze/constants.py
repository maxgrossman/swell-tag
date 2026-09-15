import bronze.ushlc_stations
import bronze.ndbc_stations
import bronze.era5_cells

import archive_builders.build_ushlc_archive
import archive_builders.build_ndbc_archive
import archive_builders.build_era5_archive
import archive_builders.build_coast_data
import archive_builders.build_ndbc_station_dims
import archive_builders.build_ushlc_station_dims

EVENT_TO_PART_MAP = {
    'ushlc': bronze.ushlc_stations.build_bronze_partitions,
    'ndbc': bronze.ndbc_stations.build_bronze_partitions,
    'era5': bronze.era5_cells.build_bronze_partitions
}

EVENT_TO_BRONZE_MAP = {
    'ushlc': bronze.ushlc_stations.build_bronze_layer,
    'ndbc': bronze.ndbc_stations.build_bronze_layer,
    'era5': bronze.era5_cells.build_bronze_layer,
}

EVENT_TO_ARCHIVE_FUNCS = {
    'ushlc': [(archive_builders.build_ushlc_archive.write_uh_slc_to_s3, 'ushlc_archive.csv')],
    'ndbc': [(archive_builders.build_ndbc_archive.write_standard_met_to_s3, 'ndbc_archive.csv')],
    'era5': [(archive_builders.build_era5_archive.write_era5_to_s3, 'era5_archive.csv')],
    'ndbc_stations_dims': [(archive_builders.build_ndbc_station_dims.write_ndbc_dims_to_s3, 'ndbc_station_dims.parquet')],
    'ushlc_stations_dims': [(archive_builders.build_ushlc_station_dims.write_uhslc_dims_to_s3, 'ushlc_station_dims.parquet')]
}

SHARED_ARCHIVE_FUNCS = [
    (archive_builders.build_coast_data.write_coast_h3s_to_s3, 'coast_lines.parquet'),
    (archive_builders.build_coast_data.write_coast_lookups_to_s3, 'coast_lookups.parquet'),
    (archive_builders.build_coast_data.write_wgs84_coast_to_s3, 'coast_h3s.parquet'),
    (archive_builders.build_coast_data.write_coast_h3s_dissolved_to_s3, 'coast_h3s.dissolved.parquet')
]