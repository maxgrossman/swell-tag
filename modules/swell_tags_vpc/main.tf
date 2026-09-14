terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # Specify a version constraint that matches your root configuration
      version = "~> 6.0"
    }
  }
}

resource "aws_vpc" "swell_tags" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support   = true
    enable_dns_hostnames = true
    tags = {
        Name = "swell_tags"
    }
}

resource "aws_vpc_endpoint" "s3_gateway" {
    vpc_id       = aws_vpc.swell_tags.id
    service_name = "com.amazonaws.${resource.aws_vpc.swell_tags.region}.s3"
}

resource "aws_security_group" "ecs_task_security_group" {
    name   = "swell_tags_ecs_security_group"
    vpc_id = aws_vpc.swell_tags.id
}

resource "aws_vpc_security_group_egress_rule" "ecr_task_egress_s3" {
    security_group_id = aws_security_group.ecs_task_security_group.id
    prefix_list_id    = aws_vpc_endpoint.s3_gateway.prefix_list_id
    ip_protocol       = "tcp"
    from_port         = 443
    to_port           = 443
}

output "vcp_id" {
    value = aws_vpc.swell_tags.id
}

output "vpc_cidr_block" {
    value = aws_vpc.swell_tags.cidr_block
}

output "vpc_s3_gateway_id" {
    value = resource.aws_vpc_endpoint.s3_gateway.id
}

output "ecs_security_group_id" {
    value = resource.aws_security_group.ecs_task_security_group.id
}
