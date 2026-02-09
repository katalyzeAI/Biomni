output "instance_id" {
  description = "Tailscale router EC2 instance ID"
  value       = aws_instance.router.id
}

output "private_ip" {
  description = "Private IP of the Tailscale router"
  value       = aws_instance.router.private_ip
}

output "security_group_id" {
  description = "Security group ID of the Tailscale router"
  value       = aws_security_group.tailscale.id
}
