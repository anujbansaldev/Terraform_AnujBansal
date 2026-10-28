output "frontend_url" {
  description = "Public URL for the Express frontend through the ALB."
  value       = "http://${aws_lb.this.dns_name}/"
}

output "backend_health_url" {
  description = "Public ALB route to the private Flask health endpoint."
  value       = "http://${aws_lb.this.dns_name}/api/health"
}

output "backend_ecr_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "frontend_ecr_repository_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}
