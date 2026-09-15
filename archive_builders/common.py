import os
os.environ['HOME'] = os.getenv("TMP_DIR", '/tmp')

import duckdb
lambda_duck = duckdb

def tmp_dir():
    return os.getenv("TMP_DIR", "/tmp")

def setup(connection: duckdb.DuckDBPyConnection):
    connection.execute('SET extension_directory = $extension_directory', {
        'extension_directory': os.getenv('DUCKDB_EXTENSIONS_DIRECTORY', '/var/task')
    })
    connection.load_extension('httpfs')
    connection.execute("CREATE OR REPLACE SECRET my_aws_secret (TYPE s3, PROVIDER credential_chain);")
    connection.execute('SET temp_directory = $home', {'home': os.environ['HOME']})