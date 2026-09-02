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

module "s3" {
  source = "./modules/s3"
  swell_tags_step_arn = module.iam.swell_tags_step_role
  power_user_role_arn = module.iam.power_user_role
  admin_user_role_arn = module.iam.admin_user_role
}

module "step_function" {
  source = "./modules/step_function" 
  swell_tags_step_arn = module.iam.swell_tags_step_role
  swell_tags_ecr_repo = module.ecr.swell_tags_ecr_repo
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}
