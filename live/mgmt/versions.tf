terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  # Replace the bucket with the StateBucketName output of the bootstrap stack.
  backend "s3" {
    bucket       = "tf-state-266735808127-identity-lab"
    key          = "identity/mgmt/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Repo      = "identity-tf-lab"
    }
  }
}
