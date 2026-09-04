resource "aws_rds_cluster" "swell_tags" {
  cluster_identifier = "swell-tags"
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = "13.6"
  database_name      = "swell_tags"
  master_username    = "stoke_lord"
  manage_master_user_password = true
  storage_encrypted  = true

  serverlessv2_scaling_configuration {
    max_capacity             = 1.0
    min_capacity             = 0.0
    seconds_until_auto_pause = 300 # only need 5 minutes.
  }
}

resource "aws_rds_cluster_instance" "swell_tags" {
  cluster_identifier = aws_rds_cluster.swell_tags
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.swell_tags.engine
  engine_version     = aws_rds_cluster.swell_tags.engine_version
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