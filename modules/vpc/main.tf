terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # Specify a version constraint that matches your root configuration
      version = "~> 6.0"
    }
  }
}

data "aws_region" "current" {}
data "aws_vpc" "default_vpc" { tags = { environment = "default_vpc" }}
data "aws_availability_zones" "current" {
    state = "available"
    region = data.aws_region.current.region
}

# NEED 2 SUBNETS FOR THE AURORA CLUSTER TO SIT IN
resource "aws_subnet" "aurora_subnet_a" {
    vpc_id = data.aws_vpc.default_vpc.id
    availability_zone = data.aws_availability_zones.current.names[0]
    cidr_block = "172.31.97.0/24"
}
resource "aws_subnet" "aurora_subnet_b" {
    vpc_id = data.aws_vpc.default_vpc.id
    availability_zone = data.aws_availability_zones.current.names[1]
    cidr_block = "172.31.98.0/24"
}

# NEED SEPARATE SUBNET FOR THE LAMBDA FUNCTIONS
resource "aws_subnet" "lambda_subnet" {
    vpc_id = data.aws_vpc.default_vpc.id
    cidr_block = "172.31.99.0/24"
}

resource "aws_security_group" "lambda_security_group" {
    name        = "step-function-lambda-security-group"
    description = "security group lambda functions that need to write to sqlmesh postgres live"

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "aurora_security_group" {
    name        = "step-function-aurora-security-group"
    description = "security group aurora db lives in"

    ingress {
        description = "Allow database access"
        from_port   = 5342
        to_port     = 5342
        protocol    = "tcp"
        security_groups = [aws_security_group.lambda_security_group.id]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

output "aurora_security_group" {
    value = aws_security_group.aurora_security_group.id
}

output "lambda_security_group" {
    value = aws_security_group.lambda_security_group.id
}

output "lambda_subnet" {
    value = aws_subnet.lambda_subnet.id
}

output "aurora_subnets" {
    value = [aws_subnet.aurora_subnet_a.id, aws_subnet.aurora_subnet_b.id]
}
