terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # Specify a version constraint that matches your root configuration
      version = "~> 6.0"
    }
  }
}

data "aws_region" "subnet_region" {}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ecs_tasks_security_group_id" {
  type = string
}

variable "vpc_id" {
  type = string
}

data "aws_vpc" "target_vpc" {
  id = var.vpc_id
}

resource "aws_security_group" "vpc_endpoint_security_group" {
  name_prefix = "vpc-endpoints-"
  vpc_id      = var.vpc_id
  description = "Security group for VPC Interface Endpoints"

  # Allow HTTPS from the entire VPC CIDR
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [var.ecs_tasks_security_group_id]
    description = "HTTPS from VPC"
  }

  # Allow all outbound (conservative default for endpoint security groups)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "vpc-endpoints-sg"
  }
}


resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.subnet_region.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoint_security_group.id]
  tags = {}
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.subnet_region.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids         = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoint_security_group.id]
  tags = {}
}


resource "aws_vpc_endpoint" "cloudwatch_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.subnet_region.region}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids         = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoint_security_group.id]
  tags = {}
}

resource "aws_vpc_security_group_egress_rule" "ecs_subnet_interface_endpoint_allow" {
    security_group_id            = var.ecs_tasks_security_group_id
    referenced_security_group_id = aws_security_group.vpc_endpoint_security_group.id
    ip_protocol                  = "tcp"
    from_port                    = 443
    to_port                      = 443
}
