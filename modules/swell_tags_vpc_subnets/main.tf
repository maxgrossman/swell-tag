terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # Specify a version constraint that matches your root configuration
      version = "~> 6.0"
    }
  }
}

variable "swell_tags_vpc_id" {
    type = string
}

variable "swell_tags_vpc_cidr_block" {
    type = string
}

variable "swell_tags_private_cidr_block" {
    type = string
}

variable "swell_tags_vpc_s3_gateway_id" {
    type = string
}

variable "swell_tags_availability_zone" {
    type = string
}

# private subnet
resource "aws_subnet" "swell_tags_ecs_private" {
    vpc_id            = var.swell_tags_vpc_id
    availability_zone = var.swell_tags_availability_zone
    cidr_block        = var.swell_tags_private_cidr_block
}

resource "aws_route_table" "swell_tags_ecs_private_rt" {
    vpc_id = var.swell_tags_vpc_id
    route  = []
}

resource "aws_vpc_endpoint_route_table_association" "s3_endpoint_association" {
    vpc_endpoint_id = var.swell_tags_vpc_s3_gateway_id
    route_table_id  = aws_route_table.swell_tags_ecs_private_rt.id
}

resource "aws_route_table_association" "swell_tags_rt_assoc" {
  subnet_id      = aws_subnet.swell_tags_ecs_private.id
  route_table_id = aws_route_table.swell_tags_ecs_private_rt.id
}


output "subnet_id" {
    value = aws_subnet.swell_tags_ecs_private.id
}