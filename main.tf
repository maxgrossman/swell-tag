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
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.28.1"
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

provider "cloudflare" {}

# Configure the AWS Providers
provider "aws" {
  alias = "us_west_2"
  region = "us-west-2"
}

variable "cloudflare_account_id" {
  type        = string
  description = "my account id"
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

module "s3_us_east_1" {
  source = "./modules/s3"
  bucket_suffix = "us-east-1"
  step_function_role_arn   = module.iam.step_function_role_arn
  swell_tags_step_arn = module.iam.swell_tags_step_role
  power_user_role_arn = module.iam.power_user_role
  admin_user_role_arn = module.iam.admin_user_role
  providers = { aws = aws.us_east_1 }
}

module "s3_us_west_2" {
  source = "./modules/s3"
  bucket_suffix = "us-west-2"
  step_function_role_arn   = module.iam.step_function_role_arn
  swell_tags_step_arn = module.iam.swell_tags_step_role
  power_user_role_arn = module.iam.power_user_role
  admin_user_role_arn = module.iam.admin_user_role
  providers = { aws = aws.us_west_2 }
}

module "swell_tags_vpc_us_east_1" {
  source = "./modules/swell_tags_vpc"
  providers = { aws = aws.us_east_1 }
}


data "aws_availability_zones" "us_east_1" {
  state = "available"
  region = "us-east-1"
}

module "swell_tags_vpc_us_west_2" {
  source = "./modules/swell_tags_vpc"
  providers = { aws = aws.us_west_2 }
}


data "aws_availability_zones" "us_west_2" {
  state = "available"
  region = "us-west-2"
}

locals {
  us_west_2_availability_zones = toset(data.aws_availability_zones.us_west_2.names)
  us_east_1_availability_zones = toset(data.aws_availability_zones.us_east_1.names)
}


module "swell_tags_vpc_subnets_us_east_1" {
  source = "./modules/swell_tags_vpc_subnets"
  for_each = local.us_east_1_availability_zones
  swell_tags_vpc_id             = module.swell_tags_vpc_us_east_1.vpc_id
  swell_tags_availability_zone  = each.value
  swell_tags_vpc_cidr_block     = module.swell_tags_vpc_us_east_1.vpc_cidr_block
  swell_tags_private_cidr_block = cidrsubnet(
    module.swell_tags_vpc_us_east_1.vpc_cidr_block, 8,
    index(tolist(local.us_east_1_availability_zones), each.value)
  )
  swell_tags_private_rt_id      = module.swell_tags_vpc_us_east_1.swell_tags_private_rt_id
  swell_tags_public_rt_id       = module.swell_tags_vpc_us_east_1.swell_tags_public_rt_id
  num_availability_zones        = length(local.us_east_1_availability_zones)
  providers = { aws = aws.us_east_1 }
}

module "swell_tags_vpc_nacls_us_east_1" {
  source                    = "./modules/swell_tags_vpc_nacls"
  swell_tags_vpc_id         = module.swell_tags_vpc_us_east_1.vpc_id
  swell_tags_public_subnets = [for subnet in module.swell_tags_vpc_subnets_us_east_1: subnet.public_subnet_id]
  providers = { aws = aws.us_east_1 }
}

module "swell_tags_vpc_subnets_us_west_2" {
  source = "./modules/swell_tags_vpc_subnets"
  for_each = local.us_west_2_availability_zones
  swell_tags_vpc_id             = module.swell_tags_vpc_us_west_2.vpc_id
  swell_tags_availability_zone  = each.value
  swell_tags_vpc_cidr_block     = module.swell_tags_vpc_us_west_2.vpc_cidr_block
  swell_tags_private_cidr_block = cidrsubnet(
    module.swell_tags_vpc_us_west_2.vpc_cidr_block, 8,
    index(tolist(local.us_west_2_availability_zones), each.value)
  )
  swell_tags_private_rt_id      = module.swell_tags_vpc_us_west_2.swell_tags_private_rt_id
  swell_tags_public_rt_id       = module.swell_tags_vpc_us_west_2.swell_tags_public_rt_id
  num_availability_zones        = length(local.us_west_2_availability_zones)
  providers = { aws = aws.us_west_2 }
}

module "swell_tags_vpc_nacls_us_west_2" {
  source                    = "./modules/swell_tags_vpc_nacls"
  swell_tags_vpc_id         = module.swell_tags_vpc_us_west_2.vpc_id
  swell_tags_public_subnets = [for subnet in module.swell_tags_vpc_subnets_us_west_2: subnet.public_subnet_id]
  providers = { aws = aws.us_west_2 }
}

module "aurora_us_east_1" {
  source = "./modules/aurora"
  step_function_role_name = module.iam.step_function_role_name
  security_groups        = [module.swell_tags_vpc_us_east_1.aurora_security_group_id]
  client_security_groups = [module.swell_tags_vpc_us_east_1.ecs_security_group_id]
  subnet_ids             = [for subnet in module.swell_tags_vpc_subnets_us_east_1: subnet.subnet_id]
  providers              = { aws = aws.us_east_1 }
}

module "ecs_bronze_layer_us_west_2" {
  source = "./modules/ecs"
  providers = { aws = aws.us_west_2 }
  step_function_ecs_arn =  module.iam.step_function_ecs_arn
  step_function_role_arn = module.iam.step_function_role_arn
  step_function_role_name = module.iam.step_function_role_name
  swell_tags_ecr_repo = module.ecr_us_west_2.swell_tags_ecr_repo
  task_name           = "bronze_layer_us_west_2"
  tasks = {
    "handler_bronze_layer" = {
      name             = "handler_bronze_layer_worker"
      cpu              = 4096
      memory           = 16384
      python_snippet   = "import handlers.handler_bronze_layer; handlers.handler_bronze_layer.handler_ecs()"
    }
  }
}

module "ecs_silver_gold_us_east_1" {
  source = "./modules/ecs"
  providers = { aws = aws.us_east_1 }
  step_function_ecs_arn =  module.iam.step_function_ecs_arn
  step_function_role_arn = module.iam.step_function_role_arn
  step_function_role_name = module.iam.step_function_role_name
  swell_tags_ecr_repo = module.ecr_us_east_1.swell_tags_ecr_repo
  task_name           = "silver_gold_us_east_1"
  tasks = {
    "handler_select_baseline" = {
        name = "handler_select_baseline_worker"
        cpu              = 1024
        memory           = 2048
        python_snippet   = "import handlers.handler_select_baseline; handlers.handler_select_baseline.handler_ecs()"
    },
    "handler_build_missing_intervals" = {
        name             = "handler_build_missing_intervals_worker"
        cpu              = 256
        memory           = 512
        python_snippet   = "import handlers.handler_build_missing_intervals; handlers.handler_build_missing_intervals.handler_ecs()"
    },
    "handler_select_interval" = {
        name = "handler_select_interval_worker"
        cpu              = 8192
        memory           = 16384
        python_snippet   = "import handlers.handler_select_interval; handlers.handler_select_interval.handler_ecs()"
    }
  }
}


module "ecs_export_swell_tags_us_east_1" {
  source = "./modules/ecs"
  providers = { aws = aws.us_east_1 }
  step_function_ecs_arn =  module.iam.step_function_ecs_arn
  step_function_role_arn = module.iam.step_function_role_arn
  step_function_role_name = module.iam.step_function_role_name
  swell_tags_ecr_repo = module.ecr_us_east_1.swell_tags_ecr_repo
  task_name           = "export_swell_tags_us_east_1"
  tasks = {
    "handler_export_swell_tags" = {
        name = "handler_export_swell_tags_worker"
        cpu              = 8192
        memory           = 16384
        python_snippet   = "import handlers.handler_export_swell_tags; handlers.handler_export_swell_tags.handler_ecs()"
    }
  }
}

module "bronze_archive_us_east_1" {
  source = "./modules/step_function"
  function_suffix = "us_east_1"
  providers = { aws = aws.us_east_1 }
  step_function_role_arn = module.iam.step_function_role_arn
  step_function_role_id = module.iam.step_function_role_id
  swell_tags_step_arn = module.iam.swell_tags_step_role
  swell_tags_step_name = module.iam.swell_tags_step_role_name
  swell_tags_ecr_repo = module.ecr_us_east_1.swell_tags_ecr_repo
  security_groups     = [module.swell_tags_vpc_us_east_1.ecs_security_group_id]
  subnet_ids          = [for subnet in module.swell_tags_vpc_subnets_us_east_1: subnet.subnet_id]
  step_function_asl = "bronze_archive_dims.json.asl"
  state_machine_name = "bronze_archive_dims_us_east_1"
  step_lambdas        = {
      "handler_build_archives" = {
          handler = "handler_build_archives"
          lambda_memory = 1024
          ephemeral_storage = 1024
          timeout = 240
      }
  }
  step_lambda_env_vars = {
      SWELL_TAGS_BUCKET = module.s3_us_east_1.swell_tags_bucket_uri
      PYTHONPATH = "/var/task"
  }
  ecs_tasks          = {}
  ecs_env_vars       = {}
  ecs_subnets        = []
  bronze_layer_ecs_cluster_arn = module.ecs_bronze_layer_us_west_2.bronze_layer_ecs_cluster_arn
}

module "export_swell_tags_east_1" {
  source = "./modules/step_function"
  function_suffix = "us_east_1"
  providers = { aws = aws.us_east_1 }
  step_function_role_arn = module.iam.step_function_role_arn
  step_function_role_id = module.iam.step_function_role_id
  swell_tags_step_arn = module.iam.swell_tags_step_role
  swell_tags_step_name = module.iam.swell_tags_step_role_name
  swell_tags_ecr_repo = module.ecr_us_east_1.swell_tags_ecr_repo
  security_groups     = [module.swell_tags_vpc_us_east_1.ecs_security_group_id]
  subnet_ids          = [for subnet in module.swell_tags_vpc_subnets_us_east_1: subnet.public_subnet_id]
  step_function_asl = "export_swell_tags.asl"
  state_machine_name = "export_swell_tags_us_east_1"
  step_lambdas        = {}
  step_lambda_env_vars = {}
  bronze_layer_ecs_cluster_arn = module.ecs_export_swell_tags_us_east_1.bronze_layer_ecs_cluster_arn
  ecs_tasks                    = module.ecs_export_swell_tags_us_east_1.ecs_tasks
  ecs_env_vars                 = {
    PYTHONPATH      = "/var/task"
    SQLMESH_GATEWAY = "duckdb_s3"
    SQLMESH_PATH    = "bin/sqlmesh"
    SQLMESH_LOG_DIR = "/tmp"
    SQLMESH_CONFIG_PATH = "/var/task"
    SQLMESH_DEBUG       = "true"
    SQLMESH_CACHE_DIR   = "/tmp/cache_dir"
    SWELL_TAGS_BUCKET   = module.s3_us_east_1.swell_tags_bucket_uri
    MAX_FORK_WORKERS    = "1"
    SQLMESH__DISABLE_ANONYMIZED_ANALYTICS = "true"
    SQLMESH_HOME  = "/tmp"
    PGDATABASE    = module.aurora_us_east_1.database_name,
    PGHOST        = module.aurora_us_east_1.database_host,
    PGUSER        = module.aurora_us_east_1.database_user,
    PGPORT        = module.aurora_us_east_1.database_port,
    PGCONNECT_TIMEOUT = 60, # so high because the 'serverless' aurora some time needs to come back to life
    PGSSLMODE     = "verify-full",
    PGSSLROOTCERT = "/var/tasks/root.crt"
    RDSSECRETARN  = module.aurora_us_east_1.database_creds_arn
    DUCKLAKE_DATAPATH = "s3://swell-tags-us-east-1/swell-tags-ducklake"
    DATA_INLINING_ROW_LIMIT = 5000
  }
  ecs_subnets                  = [for subnet in module.swell_tags_vpc_subnets_us_east_1: subnet.public_subnet_id]
  ecs_security_group_id        = module.swell_tags_vpc_us_east_1.ecs_security_group_id
  database_creds_arn           = module.aurora_us_east_1.database_creds_arn
}

module "silver_and_goald_us_east_1" {
  source = "./modules/step_function"
  function_suffix = "us_east_1"
  providers = { aws = aws.us_east_1 }
  step_function_role_arn = module.iam.step_function_role_arn
  step_function_role_id = module.iam.step_function_role_id
  swell_tags_step_arn = module.iam.swell_tags_step_role
  swell_tags_step_name = module.iam.swell_tags_step_role_name
  swell_tags_ecr_repo = module.ecr_us_east_1.swell_tags_ecr_repo
  security_groups     = [module.swell_tags_vpc_us_east_1.ecs_security_group_id]
  subnet_ids          = [for subnet in module.swell_tags_vpc_subnets_us_east_1: subnet.public_subnet_id]
  step_function_asl = "silver_gold_archive.json.asl"
  state_machine_name = "silver_and_gold_us_east_1"
  step_lambdas        = {}
  step_lambda_env_vars = {}
  bronze_layer_ecs_cluster_arn = module.ecs_silver_gold_us_east_1.bronze_layer_ecs_cluster_arn
  ecs_tasks                    = module.ecs_silver_gold_us_east_1.ecs_tasks
  ecs_env_vars                 = {
    PYTHONPATH      = "/var/task"
    SQLMESH_GATEWAY = "duckdb_s3"
    SQLMESH_PATH    = "bin/sqlmesh"
    SQLMESH_LOG_DIR = "/tmp"
    SQLMESH_CONFIG_PATH = "/var/task"
    SQLMESH_DEBUG       = "true"
    SQLMESH_CACHE_DIR   = "/tmp/cache_dir"
    SWELL_TAGS_BUCKET   = module.s3_us_east_1.swell_tags_bucket_uri
    MAX_FORK_WORKERS    = "1"
    SQLMESH__DISABLE_ANONYMIZED_ANALYTICS = "true"
    SQLMESH_HOME  = "/tmp"
    PGDATABASE    = module.aurora_us_east_1.database_name,
    PGHOST        = module.aurora_us_east_1.database_host,
    PGUSER        = module.aurora_us_east_1.database_user,
    PGPORT        = module.aurora_us_east_1.database_port,
    PGCONNECT_TIMEOUT = 60, # so high because the 'serverless' aurora some time needs to come back to life
    PGSSLMODE     = "verify-full",
    PGSSLROOTCERT = "/var/tasks/root.crt"
    RDSSECRETARN  = module.aurora_us_east_1.database_creds_arn
    DUCKLAKE_DATAPATH = "s3://swell-tags-us-east-1/swell-tags-ducklake"
    DATA_INLINING_ROW_LIMIT = 5000
  }
  ecs_subnets                  = [for subnet in module.swell_tags_vpc_subnets_us_east_1: subnet.public_subnet_id]
  ecs_security_group_id        = module.swell_tags_vpc_us_east_1.ecs_security_group_id
  database_creds_arn           = module.aurora_us_east_1.database_creds_arn
}


module "bronze_archive_us_west_2" {
  source = "./modules/step_function"
  function_suffix = "us_west_2"
  providers = { aws = aws.us_west_2 }
  step_function_role_arn = module.iam.step_function_role_arn
  step_function_role_id = module.iam.step_function_role_id
  swell_tags_step_arn = module.iam.swell_tags_step_role
  swell_tags_step_name = module.iam.swell_tags_step_role_name
  swell_tags_ecr_repo = module.ecr_us_east_1.swell_tags_ecr_repo
  security_groups     = [module.swell_tags_vpc_us_west_2.ecs_security_group_id]
  subnet_ids          = [for subnet in module.swell_tags_vpc_subnets_us_west_2: subnet.subnet_id]
  step_function_asl = "bronze_archive.json_with_ecs.asl"
  state_machine_name = "bronze_archive_us_west_2"
  step_lambdas        = {
      "handler_build_archives" = {
          handler = "handler_build_archives"
          lambda_memory = 1024
          ephemeral_storage = 1024
          timeout = 240
      },
      "handler_bronze_partitions" = {
          handler = "handler_bronze_partitions"
          lambda_memory = 512
          ephemeral_storage = 512
          timeout = 240
      },
      "handler_bronze_layer" = {
          handler = "handler_bronze_layer"
          lambda_memory = 3008
          ephemeral_storage = 4096
          timeout = 900
      }
  }
  step_lambda_env_vars = {
      SWELL_TAGS_BUCKET = module.s3_us_west_2.swell_tags_bucket_uri
      PYTHONPATH = "/var/task"
  }
  bronze_layer_ecs_cluster_arn = module.ecs_bronze_layer_us_west_2.bronze_layer_ecs_cluster_arn
  ecs_tasks                    = module.ecs_bronze_layer_us_west_2.ecs_tasks
  ecs_env_vars                 = {}
  ecs_subnets                  = [for subnet in module.swell_tags_vpc_subnets_us_west_2: subnet.subnet_id]
  ecs_security_group_id        = module.swell_tags_vpc_us_west_2.ecs_security_group_id
}

locals {
  step_function_arns = concat(
    module.bronze_archive_us_east_1.function_arns,
    module.bronze_archive_us_west_2.function_arns
  )
}

resource "aws_iam_role_policy" "step_function_policy" {
  name = "step_function_lambda_policy"
  role = module.iam.step_function_role_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = local.step_function_arns
      },
      {
        Effect   = "Allow"
        Action   = ["ecs:RunTask"]
        Resource = [for key, task in module.ecs_bronze_layer_us_west_2.ecs_tasks : "${task.arn}:${task.revision}"]
      },
    ]
  })
}

resource "aws_iam_role_policy" "ecs_states_policy" {
  name = "ecs_role_update_step_function_states"
  role = module.iam.step_function_role_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["states:SendTaskSuccess", "states:SendTaskFailure"]
        Resource = [
          module.bronze_archive_us_west_2.state_machine_arn,
          module.bronze_archive_us_east_1.state_machine_arn,
          module.silver_and_goald_us_east_1.state_machine_arn,
          module.export_swell_tags_east_1.state_machine_arn
        ]
      }
    ]
  })
}

resource "cloudflare_r2_bucket" "swell-tag" {
  account_id = var.cloudflare_account_id
  name       = "swell-tag"
  location   = "WNAM"
}

output "ecs_tasks_us_west_2" {
  value = module.ecs_bronze_layer_us_west_2.ecs_tasks
}