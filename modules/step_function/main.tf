terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # Specify a version constraint that matches your root configuration
      version = "~> 6.0"
    }
  }
}

variable "bronze_layer_ecs_cluster_arn" {
  type = string
}

variable "function_suffix" {
  type = string
}

variable "step_function_role_arn" {
  type = string
}

variable "step_function_role_id" {
  type = string
}

variable "state_machine_name" {
  type = string
}

variable "step_function_asl" {
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

variable "ecs_subnets" {
  type = list(string)
}

variable "ecs_security_group_id" {
  type = string
  default = ""
}

variable "step_lambdas" {
    type = map(object({
      handler = string
      timeout = string
      lambda_memory = number
      ephemeral_storage = number
    }))
}

variable "database_creds_arn" {
    type = string
    default = ""
}

variable "ecs_tasks" {
  type = map(object({
    name               = string
    arn                = string
    revision           = string
    container_template = string
  }))
}

variable "ecs_env_vars" {
  type = map(string)
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
  function_name = "${each.key}_${var.function_suffix}"
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

  tags = {
    Name = "${each.key}"
    Environment = "Prod"
    Service = "lambda"
    ManagedBy = "tofu"
  }
}

# i think if i was to factor out the lambda stuff into its own module,
# i could just pass whatever the heck i want in a a 'template this' map.
# and then I could get rid of this mashugg.
locals {
  lambda_func_vars = tomap({
     for func in aws_lambda_function.function:
      replace(func.function_name, "_${var.function_suffix}", "")  => func.arn
  })
  ecs_task_vars = length(var.ecs_tasks) == 0 ? {} : merge(
    { for key, task in var.ecs_tasks: task.name => task.arn },
    { for key, task in var.ecs_tasks: "${task.name}_revision" => task.revision },
    { for key, task in var.ecs_tasks: task.container_template => task.name},
    { for i, subnet in var.ecs_subnets: "ecs_private_subnet_${tostring(i)}" => subnet},
    { "ecs_task_security_group": var.ecs_security_group_id },
    { "ecs_cluster": var.bronze_layer_ecs_cluster_arn },
    var.ecs_env_vars
  )
  template_vars = merge(local.ecs_task_vars, local.lambda_func_vars)
}

resource "aws_sfn_state_machine" "state_machine" {
  name     = var.state_machine_name
  role_arn = var.step_function_role_arn
  definition = templatefile("${path.module}/../../step_functions/${var.step_function_asl}",local.template_vars)
}

output "function_arns" {
  value = [for func in aws_lambda_function.function : func.arn]
}
