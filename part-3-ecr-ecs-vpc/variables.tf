variable "aws_region" {
  description = "AWS region for Task 3. Confirm this before deployment."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Unique prefix for Task 3 resources."
  type        = string
  default     = "terraform-assignment-part-3"
}

variable "vpc_cidr" {
  description = "Dedicated VPC CIDR."
  type        = string
  default     = "10.30.0.0/16"
}

variable "availability_zones" {
  description = "Exactly two AZs in aws_region."
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]

  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "availability_zones must contain exactly two distinct AZs."
  }
}

variable "frontend_image" {
  description = "Fully qualified ECR image URI for the Express frontend."
  type        = string
}

variable "backend_image" {
  description = "Fully qualified ECR image URI for the Flask backend."
  type        = string
}

variable "task_cpu" {
  description = "Fargate task CPU units for each service."
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Fargate task memory in MiB for each service."
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Number of tasks per ECS service."
  type        = number
  default     = 1

  validation {
    condition     = var.desired_count >= 1
    error_message = "desired_count must be at least 1."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention period."
  type        = number
  default     = 7
}
