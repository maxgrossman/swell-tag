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

# Create the ZIP file
data "archive_file" "python_layer" {
  type        = "zip"
  source_dir  = "${path.module}/layers/python/package"
  output_path = "${path.module}/layers/python/layer.zip"

  depends_on = [terraform_data.python_layer_deps]
}

# Create the Lambda layer
resource "aws_lambda_layer_version" "python_deps" {
  layer_name          = "python-common-deps"
  description         = "Common Python dependencies (requests, boto3, etc.)"
  filename            = data.archive_file.python_layer.output_path
  source_code_hash    = data.archive_file.python_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]

  # Optional: compatible architectures
  compatible_architectures = ["x86_64"]
}

# Package shared utility code
data "archive_file" "handler_layer" {
  type        = "zip"
  source_dir  = "${path.module}/layers/handlers/package"
  output_path = "${path.module}/layers/handlers/layer.zip"
}

resource "aws_lambda_layer_version" "handlers" {
  layer_name          = "swell-tag-handlers"
  description         = "Shared handler code"
  filename            = data.archive_file.handler_layer.output_path
  source_code_hash    = data.archive_file.handler_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
}

resource "aws_lambda_function" "validate_baseline" {
  function_name = "validate_baseline"
  handler       = "handlers.handler_ensure_dependencies"
  runtime       = "python3.12"
  role          = aws_iam_role.swell_tags_step.arn

  filename         = data.archive_file.api.output_path
  source_code_hash = data.archive_file.api.output_base64sha256

  layers = [
    aws_lambda_layer_version.python_deps.arn,
    aws_lambda_layer_version.handlers.arn,
  ]

  tags = {
    Name = "validate_baseline"
    Environment = "Prod"
    Service = "lambda"
    ManagedBy = "terraform"
  }
}

resource "aws_lambda_function" "get_new_archives_handler" {
  function_name = "get_new_archives_handler"
  handler       = "handlers.get_new_archives_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.swell_tags_step.arn

  filename         = data.archive_file.api.output_path
  source_code_hash = data.archive_file.api.output_base64sha256

  layers = [
    aws_lambda_layer_version.python_deps.arn,
    aws_lambda_layer_version.handlers.arn
  ]

  tags = {
    Name = "get_new_archives_handler"
    Environment = "Prod"
    Service = "lambda"
    ManagedBy = "terraform"
  }
}

resource "aws_lambda_function" "era5_netcdf_to_geoparquet_handler" {
  function_name = "era5_netcdf_to_geoparquet_handler"
  handler       = "handlers.era5_netcdf_to_geoparquet_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.swell_tags_step.arn

  filename         = data.archive_file.api.output_path
  source_code_hash = data.archive_file.api.output_base64sha256

  layers = [
    aws_lambda_layer_version.python_deps.arn,
    aws_lambda_layer_version.handlers.arn
  ]

  tags = {
    Name = "era5_netcdf_to_geoparquet_handler"
    Environment = "Prod"
    Service = "lambda"
    ManagedBy = "terraform"
  }
}

data "aws_iam_policy_document" "swell_tags_policy" {
  statement {
    sid    = "SwellTagsDeny"
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
  name = "archive_builder_"
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
      Resource = [
        aws_lambda_function.era5_netcdf_to_geoparquet_handler.arn,
        aws_lambda_function.validate_baseline.arn,
        aws_lambda_function.get_new_archives_handler.arn
      ]
    }]
  })
}

resource "aws_sfn_state_machine" "archive_builder" {
  name     = "archive_builder"
  role_arn = aws_iam_role.step_function_role.arn

  # Inject the Lambda ARN dynamically into the JSON template file
  definition = templatefile("${path.module}/state_machine.json.tpl", {
    validate_baseline_arn = aws_lambda_function.validate_baseline.arn,
    get_new_archives_arn = aws_lambda_function.get_new_archives_handler.arn,
    era5_netcdf_to_geoparquet_arn = aws_lambda_function.era5_netcdf_to_geoparquet_handler.arn
  })
}
