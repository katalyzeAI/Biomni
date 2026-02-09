output "alb_dns_name" {
  description = "Internal ALB DNS — accessible via Tailscale VPN only"
  value       = module.alb.alb_dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL for pushing Docker images"
  value       = module.ecr.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.service_name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for ECS task logs"
  value       = module.ecs.log_group_name
}

output "tailscale_instance_id" {
  description = "Tailscale subnet router EC2 instance ID (use SSM to connect)"
  value       = module.tailscale.instance_id
}

output "tailscale_private_ip" {
  description = "Private IP of the Tailscale subnet router"
  value       = module.tailscale.private_ip
}
