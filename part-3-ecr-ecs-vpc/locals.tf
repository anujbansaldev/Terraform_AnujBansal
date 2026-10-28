locals {
  name = var.project_name

  common_tags = {
    Project    = var.project_name
    Assignment = "TuteDude Terraform Part 3"
    ManagedBy  = "Terraform"
  }

  public_subnet_cidrs  = ["10.30.1.0/24", "10.30.2.0/24"]
  private_subnet_cidrs = ["10.30.11.0/24", "10.30.12.0/24"]
}
