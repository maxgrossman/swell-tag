terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "step_function_ecs_arn" {
    type = string
}

variable "step_function_role_arn" {
  type = string
}

variable "step_function_role_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "swell_tags_ecr_repo" {
  type = string
}

variable "tasks" {
    type = map(object({
        cpu            = string
        memory         = string
        python_snippet = string
    }))
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

resource "aws_ecs_cluster" "bronze_layer" {
  name = "bronze-layer"
}

resource "aws_ecs_task_definition" "bronze_layer_task" {
    for_each                 = var.tasks
    family                   = each.key
    network_mode             = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    cpu                      = each.value.cpu
    memory                   = each.value.memory
    execution_role_arn       = var.step_function_ecs_arn
    task_role_arn            = var.step_function_role_arn
    container_definitions    = jsonencode([{
        name      = "${each.key}_worker",
        image     = "${data.aws_ecr_repository.swell_tags.repository_url}@${data.aws_ecr_image.swell_tags_image.image_digest}"
        essential = true
        command   = ["python", "-c", each.value.python_snippet]
        logConfiguration = {
            logDriver = "awslogs"
            options = {
                "awslogs-group"         = "/ecs/${each.key}"
                "awslogs-region"        = var.aws_region,
                "awslogs-stream-prefix" = "ecs",
            }
        }
    }])
}


resource "aws_iam_policy" "step_function_role_ecs_policy" {
  name = "step-functions-ecs-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ecs:RunTask",
          "ecs:StopTask",
          "ecs:DescribeTasks"
        ]
        Resource = [
            for key, task in aws_ecs_task_definition.bronze_layer_task: [task.arn, "${task.arn}:*"]
        ]
      },
      {
        Effect   = "Allow"
        Action   = [
          "iam:PassRole"
        ]
        Resource = [
          var.step_function_ecs_arn,
          var.step_function_role_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutTargets",
          "events:PutRule",
          "events:DescribeRule"
        ]
        Resource = "arn:aws:events:*:*:rule/StepFunctionsGetEventsForECSTaskRule"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "step_function_role_ecs_policy" {
    role       = var.step_function_role_name
    policy_arn = aws_iam_policy.step_function_role_ecs_policy.arn
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  for_each          = var.tasks
  name              = "/ecs/${each.key}"
  retention_in_days = 3
}


output "bronze_layer_ecs_cluster_arn" {
    value = aws_ecs_cluster.bronze_layer.arn
}

output "ecs_tasks" {
    value = {
        for key, task in aws_ecs_task_definition.bronze_layer_task : key => {
            name = task.family
            arn  = task.arn
        }
    }
}
