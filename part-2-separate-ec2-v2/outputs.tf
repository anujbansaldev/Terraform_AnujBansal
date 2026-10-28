output "backend_instance_id" {
  description = "Backend EC2 instance ID."
  value       = aws_instance.backend.id
}

output "frontend_instance_id" {
  description = "Frontend EC2 instance ID."
  value       = aws_instance.frontend.id
}

output "backend_private_ip" {
  description = "Private IPv4 address used by the frontend to reach Flask."
  value       = aws_instance.backend.private_ip
}

output "backend_public_ip" {
  description = "Public IPv4 address of the backend instance, if assigned."
  value       = aws_instance.backend.public_ip
}

output "frontend_public_ip" {
  description = "Public IPv4 address used to access Express."
  value       = aws_instance.frontend.public_ip
}

output "frontend_url" {
  description = "Express frontend URL."
  value       = "http://${aws_instance.frontend.public_ip}:3000"
}

output "backend_health_url" {
  description = "Private Flask health URL; check from the frontend instance or another authorized network location."
  value       = "http://${aws_instance.backend.private_ip}:5000/api/health"
}

output "frontend_health_url" {
  description = "Express health URL, which also verifies frontend-to-backend communication."
  value       = "http://${aws_instance.frontend.public_ip}:3000/api/health"
}
