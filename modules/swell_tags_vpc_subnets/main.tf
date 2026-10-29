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

variable "swell_tags_public_rt_id" {
    type = string
}

variable "swell_tags_private_rt_id" {
    type = string
}

variable "swell_tags_vpc_cidr_block" {
    type = string
}

variable "swell_tags_private_cidr_block" {
    type = string
}
variable "swell_tags_availability_zone" {
    type = string
}

variable "num_availability_zones" {
    type = number
}

locals {
    priv_cidr_parts = split(".", var.swell_tags_private_cidr_block)
    # obviously there's a limit on many times i can go one offset over. but for this 'do it just one time' case, think fine.
    public_cidr_offset = tostring(tonumber(local.priv_cidr_parts[2]) + var.num_availability_zones)
    public_subnet_cidr = "${local.priv_cidr_parts[0]}.${local.priv_cidr_parts[1]}.${local.public_cidr_offset}.${local.priv_cidr_parts[3]}"
}

resource "aws_subnet" "swell_tags_ecs_public" {
    vpc_id            = var.swell_tags_vpc_id
    availability_zone = var.swell_tags_availability_zone
    cidr_block        = local.public_subnet_cidr
    tags              = {
        Name = "swell-tags-public-${var.swell_tags_availability_zone}"
    }
}

# private subnet
resource "aws_subnet" "swell_tags_ecs_private" {
    vpc_id            = var.swell_tags_vpc_id
    availability_zone = var.swell_tags_availability_zone
    cidr_block        = var.swell_tags_private_cidr_block
    tags              = {
        Name = "swell-tags-private-${var.swell_tags_availability_zone}"
    }
}

resource "aws_route_table_association" "swell_tags_rt_assoc" {
  subnet_id      = aws_subnet.swell_tags_ecs_private.id
  route_table_id = var.swell_tags_private_rt_id
}

resource "aws_route_table_association" "swell_tags_pub_rt_assoc" {
  subnet_id      = aws_subnet.swell_tags_ecs_public.id
  route_table_id = var.swell_tags_public_rt_id
}

output "subnet_id" {
    value = aws_subnet.swell_tags_ecs_private.id
}

output "public_subnet_id" {
    value = aws_subnet.swell_tags_ecs_public.id
}