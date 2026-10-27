output "instance_public_ip" {
  description = "Public IPv4 address of the application instance."
  value       = aws_instance.application.public_ip
}

output "frontend_url" {
  description = "URL for the Express frontend."
  value       = "http://${aws_instance.application.public_ip}:3000"
}

output "backend_url" {
  description = "Private Flask API health endpoint, reachable locally on the instance and through Express."
  value       = "http://127.0.0.1:5000/api/health"
}
