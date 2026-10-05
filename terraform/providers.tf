# AWS provider. Region comes from a variable so the whole lab moves regions
# by changing one value. Every resource is tagged so you can find (and destroy)
# everything this lab created.

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}
