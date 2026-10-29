import os
from sqlmesh.core.macros import macro

@macro()
def set_extensions_directory(evaluator):
     # since sqlmesh has to recall this, think env var'ing it up makes that impossible.
    return "SET extension_directory = '/var/task';"
