from sqlmesh.core.macros import macro

@macro()
def load_s3_lambda_creds(evaluator):
    return "CREATE OR REPLACE SECRET my_aws_secret (TYPE s3, PROVIDER credential_chain);"
