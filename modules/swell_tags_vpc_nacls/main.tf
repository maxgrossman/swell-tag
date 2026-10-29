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

variable "swell_tags_public_subnets" {
    type = list(string)
}

# all the public subnets, make em able to egress to igw,
# but not to anything else.
resource "aws_network_acl" "ecs_public_nacl" {
  vpc_id     = var.swell_tags_vpc_id
  subnet_ids = var.swell_tags_public_subnets

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  ingress {
    protocol        = "tcp"
    rule_no         = 101
    action          = "allow"
    ipv6_cidr_block = "::/0"
    from_port       = 1024
    to_port         = 65535
  }


  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol        = "-1"
    rule_no         = 101
    action          = "allow"
    ipv6_cidr_block = "::/0"
    from_port       = 0
    to_port         = 0
  }

  tags = {
    Name = "swell-tags-ecs-public-subnets-egress"
  }
}
