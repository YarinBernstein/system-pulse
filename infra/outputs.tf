output "frontend_url" {
  description = "Open this in your browser to see the dashboard."
  value       = "http://${aws_instance.frontend.public_ip}"
}

output "frontend_public_ip" {
  value = aws_instance.frontend.public_ip
}

output "backend_private_ip" {
  description = "Not reachable from your laptop directly - only from the frontend server."
  value       = aws_instance.backend.private_ip
}

output "redis_private_ip" {
  description = "Not reachable from anywhere except the backend server."
  value       = aws_instance.redis.private_ip
}

output "cloudwatch_log_group" {
  description = "Where to find the backend's logs in the AWS Console (CloudWatch > Log groups)."
  value       = "/system-pulse/backend"
}
