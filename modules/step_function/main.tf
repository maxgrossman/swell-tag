variable "swell_tags_step_arn" {
    type = string
}

variable "database_host" {
    type = string
} 

variable "database_port" {
    type = string
} 

variable "database_name" {
    type = string
} 

variable "database_user" {
    type = string
} 

variable "step_lambdas" {
    type = map(object({
        handler = string
        timeout = string
        lambda_memory = number
        ephemeral_storage = number
    }))

    default = {
        "handler_select_full" = {
            handler = "handler_select_full"
            lambda_memory = 512
            ephemeral_storage = 512
            timeout = 60
        },
        "handler_ensure_dependencies" = {
            handler = "handler_ensure_dependencies"
            lambda_memory = 128
            ephemeral_storage = 512
            timeout = 60
        },
        "handler_initialize_models" = {
            handler = "handler_initialize_models"
            lambda_memory = 256
            ephemeral_storage = 512
            timeout = 60
        },
        "handler_era5_get_missing" = {   
            handler = "handler_era5_get_missing"
            lambda_memory = 256
            ephemeral_storage = 512
            timeout = 60
        },
        "handler_era5_netcdf_to_geoparquet_handler" = {
            handler = "handler_era5_netcdf_to_geoparquet_handler"
            lambda_memory = 4112
            ephemeral_storage = 10240
            timeout = 60
        },
        "handler_build_missing_intervals" = {
            handler = "handler_build_missing_intervals"
            lambda_memory = 128
            ephemeral_storage = 512
            timeout = 60
        },
        "handler_select_interval" = {
            handler = "handler_select_interval"
            lambda_memory = 2056
            ephemeral_storage = 10240
            timeout = 60
        }
    }
}

variable "swell_tags_ecr_repo" {
    type = string
}

variable "swell_tags_image_version" {
    type = string 
    default = "0.0.1"
}

# Look up the existing ECR repository
data "aws_ecr_repository" "swell_tags" {
  name = var.swell_tags_ecr_repo
}

# Look up a specific image inside that repository by tag
data "aws_ecr_image" "swell_tags_image" {
  repository_name = data.aws_ecr_repository.swell_tags.name
  image_tag       = var.swell_tags_image_version
}

resource "aws_lambda_function" "function" {
  for_each      = var.step_lambdas
  function_name = each.key
  role          = var.swell_tags_step_arn

  package_type  = "Image"
  # dare i think i can rely on an image tag! use the sha brah!
  image_uri     = "${data.aws_ecr_repository.swell_tags.repository_url}@${data.aws_ecr_image.swell_tags_image.image_digest}"

  image_config {
    # Overrides the CMD instruction in the Dockerfile
    command = ["handlers.${each.value.handler}.handler"]
    working_directory = "/var/task"
  }

  environment {
    variables = {
      SQLMESH_GATEWAY = "duckdb_s3"
      SQLMESH_PATH = "bin/sqlmesh"
      SQLMESH_LOG_DIR = "/tmp"
      SQLMESH_CONFIG_PATH = "/var/task"
      SQLMESH_DEBUG = "true"
      SQLMESH_CACHE_DIR = "/tmp/cache_dir"
      PGHOST = var.database_host
      PGPORT = var.database_port
      PGUSER = var.database_user
      PGDATABASE = var.database_name
      MAX_FORK_WORKERS = 1
      SQLMESH__DISABLE_ANONYMIZED_ANALYTICS = "true"
      SQLMESH_HOME = "/tmp"
      PYTHONPATH = "/var/task"
    }
  }

  timeout = each.value.timeout

  memory_size = each.value.lambda_memory
  ephemeral_storage {
    size = each.value.ephemeral_storage
  }

  tags = {
    Name = "${each.key}"
    Environment = "Prod"
    Service = "lambda"
    ManagedBy = "tofu"
  }
}

resource "aws_iam_role" "step_function_role" {
  name = "archive_builder_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "step_function_policy" {
  name = "step_function_lambda_policy"
  role = aws_iam_role.step_function_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = [for func in aws_lambda_function.function : func.arn]
    }]
  })
}

resource "aws_sfn_state_machine" "archive_builder" {
  name     = "archive_builder"
  role_arn = aws_iam_role.step_function_role.arn

  definition = templatefile("${path.module}/../../step_functions/archive_builder.asl.json", {
    for func in aws_lambda_function.function: func.function_name => func.arn
  })
}
