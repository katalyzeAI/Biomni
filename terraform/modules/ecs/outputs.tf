output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.main.arn
}

output "service_name" {
  value = aws_ecs_service.biomni.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.biomni.arn
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.ecs.name
}
