import duckdb
extension_directory = '/opt/duckdb_extensions'
conn = duckdb.connect()
conn.execute(f"SET extension_directory = '{extension_directory}'")
conn.install_extension('spatial')
conn.install_extension('httpfs')
conn.install_extension('aws')
conn.install_extension('h3',repository='community')
conn.install_extension('webbed',repository='community')
conn.install_extension('crawler',repository='community')
conn.install_extension('zarr',repository='community')
