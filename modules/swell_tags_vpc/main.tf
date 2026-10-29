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

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.swell_tags.id
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

resource "aws_security_group" "aurora_security_group" {
    name   = "swell_tags_aurora_security_group"
    vpc_id = aws_vpc.swell_tags.id
}

resource "aws_vpc_security_group_egress_rule" "ecr_task_egress_s3" {
    security_group_id = aws_security_group.ecs_task_security_group.id
    ip_protocol       = "tcp"
    cidr_ipv4         = "0.0.0.0/0"
    from_port         = 443
    to_port           = 443
}
resource "aws_route_table" "swell_tags_ecs_public_rt" {
  vpc_id =  aws_vpc.swell_tags.id
  tags = {
    Name = "swell_tags_ecs_public_rt"
  }
}

resource "aws_route" "ecs_public_internet_access" {
  route_table_id         = aws_route_table.swell_tags_ecs_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table" "swell_tags_ecs_private_rt" {
    vpc_id = aws_vpc.swell_tags.id
    route  = []
  tags = {
    Name = "swell_tags_ecs_private_rt"
  }
}

resource "aws_vpc_endpoint_route_table_association" "s3_endpoint_association" {
    vpc_endpoint_id = aws_vpc_endpoint.s3_gateway.id
    route_table_id  = aws_route_table.swell_tags_ecs_private_rt.id
}

output "vpc_id" {
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

output "aurora_security_group_id" {
    value = resource.aws_security_group.aurora_security_group.id
}

output "igw_id" {
    value = resource.aws_internet_gateway.igw.id
}

output "swell_tags_public_rt_id" {
    value = resource.aws_route_table.swell_tags_ecs_public_rt.id
}

output "swell_tags_private_rt_id" {
    value = resource.aws_route_table.swell_tags_ecs_private_rt.id
}