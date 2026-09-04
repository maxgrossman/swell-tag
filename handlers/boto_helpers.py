import json
import os

def get_rds_secret(rds_database):
    import boto3

    rds_client = boto3.client('rds')
    secrets_client = boto3.client('secretsmanager')

    # 1. Get the Secret ARN directly from your Aurora Cluster configuration
    cluster_info = rds_client.describe_db_clusters(DBClusterIdentifier='my-aurora-cluster')
    secret_arn = cluster_info['DBClusters'][0]['MasterUserSecret']['SecretArn']

    # 2. Retrieve the secret string from Secrets Manager
    response = secrets_client.get_secret_value(SecretId=secret_arn)
    return json.loads(response['SecretString'])


def load_rds_credentials():
    secrets_json = get_rds_secret(os.getenv("SQLMESH_STATE_DATABASE", "swell-tags"))

    os.environ['PGUSER'] = secrets_json['username']
    os.environ['PGPASSWORD'] = secrets_json['password']

