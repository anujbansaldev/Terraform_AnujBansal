variable "aws_region" {
  description = "AWS region for the separate-EC2 deployment."
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type for both application instances; it must support x86_64."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair used for SSH."
  type        = string

  validation {
    condition     = length(trimspace(var.key_name)) > 0
    error_message = "key_name must name an existing EC2 key pair."
  }
}

variable "trusted_ssh_cidr" {
  description = "IPv4 CIDR allowed to SSH to either instance, preferably your public IP with /32."
  type        = string

  validation {
    condition     = can(cidrhost(var.trusted_ssh_cidr, 0)) && can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.trusted_ssh_cidr))
    error_message = "trusted_ssh_cidr must be a valid IPv4 CIDR block."
  }
}

variable "client_cidr" {
  description = "IPv4 CIDR allowed to access the frontend on TCP port 3000."
  type        = string

  validation {
    condition     = can(cidrhost(var.client_cidr, 0)) && can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.client_cidr))
    error_message = "client_cidr must be a valid IPv4 CIDR block."
  }
}

variable "vpc_id" {
  description = "VPC containing the selected public subnet."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-fA-F]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID."
  }
}

variable "subnet_id" {
  description = "Public subnet for both instances; Terraform verifies its VPC and internet-gateway route."
  type        = string

  validation {
    condition     = can(regex("^subnet-[0-9a-fA-F]+$", var.subnet_id))
    error_message = "subnet_id must be a valid subnet ID."
  }
}

variable "application_source_url" {
  description = "Public HTTPS Git repository containing applications/backend and applications/frontend."
  type        = string

  validation {
    condition     = can(regex("^https://", var.application_source_url))
    error_message = "application_source_url must be a public HTTPS Git URL."
  }
}

variable "application_source_ref" {
  description = "Git branch or tag to deploy from application_source_url."
  type        = string
  default     = "main"
}

variable "gunicorn_version" {
  description = "Pinned Gunicorn version installed separately from the shared requirements file."
  type        = string
  default     = "22.0.0"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.gunicorn_version))
    error_message = "gunicorn_version must use a pinned semantic version such as 22.0.0."
  }
}
