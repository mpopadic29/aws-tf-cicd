terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "mpopadic-tf-state-bucket"
    key            = "environments/dev/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}

provider "aws" {
  region = "eu-central-1"
}

module "logs_bucket" {
  source      = "../../modules/s3"
  environment = "dev"
}

module "ec2_instance" {
  source        = "../../modules/ec2"
  environment   = "dev"
  instance_type = "t3.micro"
}
