terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  backend "s3" {
    bucket       = "anujbansal-terraform-state-525360104564-ap-south-1"
    key          = "terraform-assignment-part-3/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
