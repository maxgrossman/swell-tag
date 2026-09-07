terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # Specify a version constraint that matches your root configuration
      version = "~> 6.0"
    }
  }
}

data "aws_iam_role" "power_user" {
  name = "AWSReservedSSO_PowerUserAccess_5a9ad12fe69c1818"
}

data "aws_iam_role" "admin_user" {
  name = "AWSReservedSSO_AdministratorAccess_3befbc9495cbc295"
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

data "aws_s3_bucket" "era5_open_registry_bucket" {
  bucket = "nsf-ncar-era5"
  region = "us-west-2"
}

data "aws_iam_policy_document" "allow_read_era5_document" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.era5_open_registry_bucket.arn}/*"]
  }
}

resource "aws_iam_policy" "era5_open_registry_bucket_read" {
    name        = "era5_open_registry_bucket_read"
    path        = "/"
    description = "Way that I believe lets me read from the open bucket since I am not ANON."
    policy = data.aws_iam_policy_document.allow_read_era5_document.json
}

data "aws_iam_policy" "basic_execution_role" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role" "swell_tags_step" {
  name               = "swell-tags-step"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json

  tags = {
    Name      = "swell-tags-step"
    Service   = "lambda"
    ManagedBy = "tofu"
    Environment = "prod"
  }
}

resource "aws_iam_role_policy_attachment" "basic_execution_role_attach" {
  role       = aws_iam_role.swell_tags_step.name
  policy_arn = data.aws_iam_policy.basic_execution_role.arn
}

resource "aws_iam_role_policy_attachment" "era5_open_registry_bucket_role_attach" {
  role       = aws_iam_role.swell_tags_step.name
  policy_arn = aws_iam_policy.era5_open_registry_bucket_read.arn
}

resource "aws_iam_role" "step_function_role" {
  name = "bronze_layer_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })
}

output "step_function_role_arn" {
    value = aws_iam_role.step_function_role.arn
}

output "step_function_role_id" {
    value = aws_iam_role.step_function_role.id
}

output "swell_tags_step_role_name" {
    value = aws_iam_role.swell_tags_step.name
}

output "swell_tags_step_role" {
    value = aws_iam_role.swell_tags_step.arn
}

output "power_user_role" {
    value = data.aws_iam_role.power_user.arn
}

output "admin_user_role" {
    value = data.aws_iam_role.admin_user.arn
}
