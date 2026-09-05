variable "swell_tags_step_name" {
    type = string
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

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
}

data "aws_iam_policy_document" "swell_tags_database_auth" {
  statement {
    sid    = "SwellTagsAllowRDSConnect"
    effect = "Allow"
    resources = [local.rds_user_arn]
    actions = ["rds-db:connect"]
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
    role       = var.swell_tags_step_name
    policy_arn = aws_iam_policy.swell_tags_database_auth.arn
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