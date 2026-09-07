terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0" # Use the latest stable 3.x version
    }
  }

  backend "s3" {
    bucket = "geowannabees-tf-remote-state"
    key    = "swell-tags"
    region = "us-east-1"
  }
}

# Configure the AWS Providers
provider "aws" {
  alias = "us_east_1"
  region = "us-east-1"
}

# Configure the AWS Providers
provider "aws" {
  alias = "us_west_2"
  region = "us-west-2"
}

module "iam" {
  source = "./modules/iam"
}

module "ecr_us_east_1" {
  source = "./modules/ecr"
  providers = { aws = aws.us_east_1 }
}

module "ecr_us_west_2" {
  source = "./modules/ecr"
  providers = { aws = aws.us_west_2 }
}

module "vpc" {
  source = "./modules/vpc"
}

module "s3_us_east_1" {
  source = "./modules/s3"
  bucket_suffix = "us-east-1"
  swell_tags_step_arn = module.iam.swell_tags_step_role
  power_user_role_arn = module.iam.power_user_role
  admin_user_role_arn = module.iam.admin_user_role
  providers = { aws = aws.us_east_1 }
}

module "s3_us_west_2" {
  source = "./modules/s3"
  bucket_suffix = "us-west-2"
  swell_tags_step_arn = module.iam.swell_tags_step_role
  power_user_role_arn = module.iam.power_user_role
  admin_user_role_arn = module.iam.admin_user_role
  providers = { aws = aws.us_west_2 }
}

module "aurora" {
  source = "./modules/aurora"
  swell_tags_step_name = module.iam.swell_tags_step_role_name
  security_groups = [module.vpc.aurora_security_group]
  subnet_ids = module.vpc.aurora_subnets
  providers = { aws = aws.us_east_1 }
}

module "bronze_archive_us_east_1" {
  source = "./modules/step_function"
  providers = { aws = aws.us_east_1 }
  step_function_role_arn = module.iam.step_function_role_arn
  step_function_role_id = module.iam.step_function_role_id
  swell_tags_step_arn = module.iam.swell_tags_step_role
  swell_tags_step_name = module.iam.swell_tags_step_role_name
  swell_tags_ecr_repo = module.ecr_us_east_1.swell_tags_ecr_repo
  security_groups     = [module.vpc.lambda_security_group]
  subnet_ids          = [module.vpc.lambda_subnet]
  step_function_name = "bronze_archive.json.asl"
  step_lambdas        = {
      "handler_build_archives" = {
          handler = "handler_build_archives"
          lambda_memory = 1024
          ephemeral_storage = 1024
          timeout = 240
      },
      "handler_bronze_partitions" = {
          handler = "handler_bronze_partitions"
          lambda_memory = 1024
          ephemeral_storage = 1024
          timeout = 240
      },
      "handler_bronze_layer" = {
          handler = "handler_bronze_layer"
          lambda_memory = 4096
          ephemeral_storage = 4096
          timeout = 900
      }
  }
  step_lambda_env_vars = {
      SQLMESH_GATEWAY = "duckdb_s3"
      SQLMESH_PATH = "bin/sqlmesh"
      SQLMESH_LOG_DIR = "/tmp"
      SQLMESH_CONFIG_PATH = "/var/task"
      SQLMESH_DEBUG = "true"
      SQLMESH_CACHE_DIR = "/tmp/cache_dir"
      SWELL_TAGS_BUCKET = "s3://swell-tags"
      MAX_FORK_WORKERS = "1"
      SQLMESH__DISABLE_ANONYMIZED_ANALYTICS = "true"
      SQLMESH_HOME = "/tmp"
      PYTHONPATH = "/var/task"
  }
}

# module "bronze_archive_us_west_2" {
#   source = "./modules/step_function"
#   providers = { aws = aws.us_west_2 }
#   swell_tags_step_arn = module.iam.swell_tags_step_role
#   swell_tags_step_name = module.iam.swell_tags_step_role_name
#   swell_tags_ecr_repo = module.ecr.swell_tags_ecr_repo
#   security_groups     = [module.vpc.lambda_security_group]
#   subnet_ids          = [module.vpc.lambda_subnet]
#   step_function_arn = module.iam.step_function_arn
#   step_function_name = "bronze_archive.json.asl"
#   step_lambdas        = {
#       "handler_build_archives" = {
#           handler = "handler_build_archives"
#           lambda_memory = 1024
#           ephemeral_storage = 1024
#           timeout = 240
#       },
#       "handler_bronze_partitions" = {
#           handler = "handler_bronze_partitions"
#           lambda_memory = 1024
#           ephemeral_storage = 1024
#           timeout = 240
#       },
#       "handler_bronze_layer" = {
#           handler = "handler_bronze_layer"
#           lambda_memory = 4096
#           ephemeral_storage = 4096
#           timeout = 900
#       }
#   }
#   step_lambda_env_vars = {
#       SQLMESH_GATEWAY = "duckdb_s3"
#       SQLMESH_PATH = "bin/sqlmesh"
#       SQLMESH_LOG_DIR = "/tmp"
#       SQLMESH_CONFIG_PATH = "/var/task"
#       SQLMESH_DEBUG = "true"
#       SQLMESH_CACHE_DIR = "/tmp/cache_dir"
#       SWELL_TAGS_BUCKET = "s3://swell-tags"
#       MAX_FORK_WORKERS = "1"
#       SQLMESH__DISABLE_ANONYMIZED_ANALYTICS = "true"
#       SQLMESH_HOME = "/tmp"
#       PYTHONPATH = "/var/task"
#   }
# }

# PGHOST = module.aurora.database_host
# PGPORT = module.aurora.database_port
# PGUSER = module.aurora.database_user
# PGDATABASE = module.aurora.database_name
# "handler_select_full" = {
#     handler = "handler_select_full"
#     lambda_memory = 512
#     ephemeral_storage = 512
#     timeout = 60
# },
# "handler_ensure_dependencies" = {
#     handler = "handler_ensure_dependencies"
#     lambda_memory = 128
#     ephemeral_storage = 512
#     timeout = 60
# },
# "handler_initialize_models" = {
#     handler = "handler_initialize_models"
#     lambda_memory = 256
#     ephemeral_storage = 512
#     timeout = 60
# },
# "handler_era5_get_missing" = {
#     handler = "handler_era5_get_missing"
#     lambda_memory = 256
#     ephemeral_storage = 512
#     timeout = 60
# },
# "handler_era5_netcdf_to_geoparquet_handler" = {
#     handler = "handler_era5_netcdf_to_geoparquet_handler"
#     lambda_memory = 4112
#     ephemeral_storage = 10240
#     timeout = 60
# },
# "handler_build_missing_intervals" = {
#     handler = "handler_build_missing_intervals"
#     lambda_memory = 128
#     ephemeral_storage = 512
#     timeout = 60
# },
# "handler_select_interval" = {
#     handler = "handler_select_interval"
#     lambda_memory = 2056
#     ephemeral_storage = 10240
#     timeout = 60
# }