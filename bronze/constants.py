import bronze.ushlc_stations
import bronze.ndbc_stations
import bronze.era5_cells

EVENT_TO_PART_MAP = {
    'ushlc': bronze.ushlc_stations.build_bronze_partitions,
    'ndbc': bronze.ndbc_stations.build_bronze_partitions,
    'era5': bronze.era5_cells.build_bronze_partitions
}

EVENT_TO_BRONZE_MAP = {
    'ushlc': bronze.ushlc_stations.build_bronze_layer,
    'ndbc': bronze.ndbc_stations.build_bronze_layer,
    'era5': bronze.era5_cells.build_bronze_layer
}