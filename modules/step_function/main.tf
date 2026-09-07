terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # Specify a version constraint that matches your root configuration
      version = "~> 6.0"
    }
  }
}

variable "step_function_role_arn" {
  type = string
}

variable "step_function_role_id" {
  type = string
}

variable "step_function_name" {
  type = string
}

variable "swell_tags_step_arn" {
    type = string
}

variable "swell_tags_step_name" {
    type = string
}

variable "subnet_ids" {
    type = list(string)
}

variable "security_groups" {
    type = list(string)
}

variable "step_lambdas" {
    type = map(object({
      handler = string
      timeout = string
      lambda_memory = number
      ephemeral_storage = number
    }))
}

variable "step_lambda_env_vars" {
  type = map(string)
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

# resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
#   role       = var.swell_tags_step_name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
# }

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
    variables = var.step_lambda_env_vars
  }

  timeout = each.value.timeout

  memory_size = each.value.lambda_memory
  ephemeral_storage {
    size = each.value.ephemeral_storage
  }

  # vpc_config {
  #   subnet_ids         = var.subnet_ids
  #   security_group_ids = var.security_groups
  # }

  # depends_on = [aws_iam_role_policy_attachment.lambda_vpc_access]

  tags = {
    Name = "${each.key}"
    Environment = "Prod"
    Service = "lambda"
    ManagedBy = "tofu"
  }
}

resource "aws_iam_role_policy" "step_function_policy" {
  name = "step_function_lambda_policy"
  role = var.step_function_role_id
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
  role_arn = var.step_function_role_arn

  definition = templatefile("${path.module}/../../step_functions/${var.step_function_name}", {
    for func in aws_lambda_function.function: func.function_name => func.arn
  })
}
