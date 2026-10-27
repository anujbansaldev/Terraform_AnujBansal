variable "aws_region" {
  description = "AWS region for the single-EC2 deployment."
  type        = string
  default     = "ap-south-1"
}

variable "ami_id" {
  description = "AMI ID for an Amazon Linux 2023 x86_64 instance in aws_region."
  type        = string
  validation {
    condition     = can(regex("^ami-[0-9a-fA-F]+$", var.ami_id))
    error_message = "ami_id must be a valid AMI ID for the selected region."
  }
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair used for SSH."
  type        = string
  validation {
    condition     = length(trimspace(var.key_name)) > 0
    error_message = "key_name must name an existing EC2 key pair."
  }
}

variable "trusted_ip_cidr" {
  description = "CIDR allowed to SSH to the instance, for example your public IP with /32."
  type        = string
  validation {
    condition     = can(cidrhost(var.trusted_ip_cidr, 0))
    error_message = "trusted_ip_cidr must be a valid IPv4 or IPv6 CIDR block."
  }
}

variable "application_source_url" {
  description = "Git URL containing applications/backend and applications/frontend."
  type        = string
  validation {
    condition     = can(regex("^https?://|^git@", var.application_source_url))
    error_message = "application_source_url must be an HTTP(S) or SSH Git URL."
  }
}

variable "application_source_ref" {
  description = "Git branch or tag to check out on the EC2 instance."
  type        = string
  default     = "main"
}
