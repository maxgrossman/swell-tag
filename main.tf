terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0" # Use the latest stable 3.x version
    }
  }

  backend "s3" {
    bucket = "geowannabees-tf-remote-state"
    key    = "swell-tags"
    region = var.aws_region
  }


}

variable "aws_region" {
  type =     string
  default = "us-east-1" 
}

module "iam" {
  source = "./modules/iam"
}

module "ecr" {
  source = "./modules/ecr"
}

module "vpc" {
  source = "./modules/vpc"
}

module "s3" {
  source = "./modules/s3"
  swell_tags_step_arn = module.iam.swell_tags_step_role
  power_user_role_arn = module.iam.power_user_role
  admin_user_role_arn = module.iam.admin_user_role
}

module "aurora" {
  source = "./modules/aurora"
  swell_tags_step_name = module.iam.swell_tags_step_role_name
  security_groups = [module.vpc.aurora_security_group]
  subnet_ids = module.vpc.aurora_subnets
}

module "step_function" {
  source = "./modules/step_function" 
  swell_tags_step_arn = module.iam.swell_tags_step_role
  swell_tags_step_name = module.iam.swell_tags_step_role_name
  swell_tags_ecr_repo = module.ecr.swell_tags_ecr_repo
  database_user       = module.aurora.database_user
  database_host       = module.aurora.database_host
  database_port       = module.aurora.database_port
  database_name       = module.aurora.database_name
  security_groups     = [module.vpc.lambda_security_group]
  subnet_ids          = [module.vpc.lambda_subnet]
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}
