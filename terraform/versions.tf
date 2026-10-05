# Provider and Terraform version constraints.
# Pinned deliberately: this is the single place to bump the AWS provider.
# Record the exact versions you last verified in ../versions.yml.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
