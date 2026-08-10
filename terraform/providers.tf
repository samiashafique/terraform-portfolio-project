terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ca-central-1"

  # Applied to every taggable resource this provider creates,
  # so cost allocation and ownership work without per-resource tagging.
  default_tags {
    tags = {
      Project   = "Portfolio Website"
      ManagedBy = "Terraform"
    }
  }
}
