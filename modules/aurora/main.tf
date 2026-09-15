terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "step_function_role_name" {
    type = string
}

variable "security_groups" {
    type = list(string)
}

variable "client_security_groups" {
    type = list(string)
}

variable "subnet_ids" {
    type = list(string)
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_db_subnet_group" "swell_tags" {
    name = "swell_tags"
    subnet_ids = var.subnet_ids
}

resource "aws_rds_cluster" "swell_tags" {
  cluster_identifier = "swell-tags"
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = "18.4"
  database_name      = "swell_tags"
  master_username    = "stoke_lord"
  manage_master_user_password = true
  storage_encrypted  = true
  iam_database_authentication_enabled = true

  serverlessv2_scaling_configuration {
    max_capacity             = 1.0
    min_capacity             = 0.0
    seconds_until_auto_pause = 300 # only need 5 minutes.
  }

  vpc_security_group_ids = var.security_groups
  db_subnet_group_name = aws_db_subnet_group.swell_tags.name

  tags = {
    Name        = "swell-tags"
    ManagedBy   = "tofu"
    Environment = "prod"
  }
}

resource "aws_rds_cluster_instance" "swell_tags" {
  cluster_identifier = aws_rds_cluster.swell_tags.cluster_identifier
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.swell_tags.engine
  engine_version     = aws_rds_cluster.swell_tags.engine_version
}

locals {
  rds_user_arn = format(
    "arn:aws:rds-db:%s:%s:dbuser:%s/%s",
    data.aws_region.current.region,
    data.aws_caller_identity.current.account_id,
    aws_rds_cluster.swell_tags.cluster_resource_id,
    aws_rds_cluster.swell_tags.master_username
  )
  client_server_sg_pairs = {
    for pair in setproduct(var.client_security_groups, var.security_groups) : "${pair[0]}-${pair[1]}" => {
      client      = pair[0]
      rds         = pair[1]
    }
  }
}

data "aws_iam_policy_document" "swell_tags_database_auth" {
  statement {
    sid    = "SwellTagsAllowRDSConnect"
    effect = "Allow"
    resources = [local.rds_user_arn]
    actions = ["rds-db:connect"]
  }
  statement {
    sid     = "SwellTagDatabaseSecret"
    effect  = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [aws_rds_cluster.swell_tags.master_user_secret[0].secret_arn]
  }
}

resource "aws_iam_policy" "swell_tags_database_auth" {
    name   = "swell_tags_database_auth"
    policy = data.aws_iam_policy_document.swell_tags_database_auth.json
    tags = {
        Name        = "swell-tags"
        ManagedBy   = "tofu"
        Environment = "prod"
    }
}

resource "aws_iam_role_policy_attachment" "swell_tag_step_database_auth" {
    role       = var.step_function_role_name
    policy_arn = aws_iam_policy.swell_tags_database_auth.arn
}

# allow outbound from sg_client -> sg_server
# allow inbound  from sg_server -> sg_client

resource "aws_vpc_security_group_egress_rule" "ecs_sg_to_rds_egress" {
    for_each                     = local.client_server_sg_pairs
    security_group_id            = each.value.client
    referenced_security_group_id = each.value.rds
    ip_protocol                  = "tcp"
    from_port                    = 5432
    to_port                      = 5432
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs_ingress" {
    for_each                     = local.client_server_sg_pairs
    security_group_id            = each.value.rds
    referenced_security_group_id = each.value.client
    ip_protocol                  = "tcp"
    from_port                    = 5432
    to_port                      = 5432
}

output "database_name" {
    value = aws_rds_cluster.swell_tags.database_name
}

output "database_host" {
    value =  aws_rds_cluster.swell_tags.endpoint
}

output "database_port" {
    value = aws_rds_cluster.swell_tags.port
}

output "database_user" {
    value = aws_rds_cluster.swell_tags.master_username
}

output "database_creds_arn" {
  value = aws_rds_cluster.swell_tags.master_user_secret[0].secret_arn
}