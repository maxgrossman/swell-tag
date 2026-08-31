variable "step_lambdas" {
  type    = list(string)
  default = [
    "handler_ensure_dependencies",
    "handler_initialize_models",
    "get_new_archives_handler",
    "era5_netcdf_to_geoparquet_handler",
    "handler_build_missing_intervals",
    "handler_select_interval"
  ]
}

variable "lambda_layers" {
  type    = list(string)
  default = [
    "python_layer",
    "handler_layer",
    "sqlmesh_layer"
  ]
}

variable "aws_region" {
  type =     string
  default = "us-east-1" 
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

data "aws_iam_role" "power_user" {
  name = "AWSReservedSSO_PowerUserAccess_5a9ad12fe69c1818"
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "swell_tags_step" {
  name               = "swell-tags-step"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json

  tags = {
    Name      = "swell-tags-step"
    Service   = "lambda"
    ManagedBy = "terraform"
    Environment = "prod"
  }
}

resource "terraform_data" "python_layer_deps" {
  triggers_replace = {
    pyprojecttoml = filesha256("${path.module}/pyproject.toml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      cp pyproject.toml layers/python
      cd ${path.module}/layers/python
      rm -rf package
      mkdir -p package/python
      python3.12 -m pip install . -t package/python --platform manylinux2014_x86_64 --implementation cp --python-version 3.12 --only-binary=:all:
    EOT
  }
}

resource "terraform_data" "sqlmesh_layer_deps" {
  triggers_replace = { 
    models = jsonencode({
      for fn in fileset("${path.module}/models", "**") :
      fn => filesha256("${path.module}/models/${fn}")
    })
    config = filesha256("${path.module}/config.yml")
  } 

  provisioner "local-exec" {
    command = <<-EOT
      rm -rf layers/sqlmesh/package/models
      cp -r models layers/sqlmesh/package/models
      cp config.yml layers/sqlmesh/package
    EOT
  }
}

data "archive_file" "python_layer" {
  type        = "zip"
  source_dir  = "${path.module}/layers/python/package"
  output_path = "${path.module}/layers/python/layer.zip"

  depends_on = [terraform_data.python_layer_deps]
}

data "archive_file" "handler_layer" {
  type        = "zip"
  source_dir  = "${path.module}/layers/handlers/package"
  output_path = "${path.module}/layers/handlers/layer.zip"
}

data "archive_file" "sqlmesh_layer" {
  type        = "zip"
  source_file = "${path.module}/config.yml"
  output_path = "${path.module}/layers/sqlmesh/layer.zip"
}

resource "aws_lambda_layer_version" "python_deps" {
  layer_name          = "python-common-deps"
  description         = "Common Python dependencies (requests, boto3, etc.)"
  filename            = data.archive_file.python_layer.output_path
  source_code_hash    = data.archive_file.python_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
  compatible_architectures = ["x86_64"]
}

resource "aws_lambda_layer_version" "handlers" {
  layer_name          = "swell-tag-handlers"
  description         = "Shared handler code"
  filename            = data.archive_file.handler_layer.output_path
  source_code_hash    = data.archive_file.handler_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
}

resource "aws_lambda_layer_version" "sqlmesh" {
  layer_name          = "sqlmesh-layer"
  description         = "the sqlmesh config and models"
  filename            = data.archive_file.sqlmesh_layer.output_path
  source_code_hash    = data.archive_file.sqlmesh_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
}

resource "aws_lambda_function" "function" {
  for_each = var.step_lambdas
  function_name = each.value
  handler       = "handlers.${each.value}"
  runtime       = "python3.12"
  role          = aws_iam_role.swell_tags_step.arn

  filename         = data.archive_file.api.output_path
  source_code_hash = data.archive_file.api.output_base64sha256

  layers = [
    aws_lambda_layer_version.python_deps.arn,
    aws_lambda_layer_version.handlers.arn,
    aws_lambda_layer_version.sqlmesh.arn
  ]

  tags = {
    Name = "${each.value}"
    Environment = "Prod"
    Service = "lambda"
    ManagedBy = "terraform"
  }
}

data "aws_iam_policy_document" "swell_tags_policy" {
  statement {
    sid    = "SwellTagsAllow"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [
        data.aws_iam_role.power_user.arn,
        data.aws_iam_role.swell_tags_step.arn
      ]
    }

    resources = [aws_s3_bucket.swell_tags.arn]

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject"
    ]
  }
}

resource "aws_s3_bucket" "swell_tags" {
  bucket = "swell-tags"

  tags = {
    Name        = "swell-tags"
    ManagedBy = "terraform"
    Environment = "prod"
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

  definition = templatefile("${path.module}/state_machine.json.tpl", {
    for func in aws_aws_lambda_function.function: func.function_name => func.arn
  })
}
