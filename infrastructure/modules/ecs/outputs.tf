output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.app.name
}

output "app_task_definition_arn" {
  value = aws_ecs_task_definition.app.arn
}

output "migrate_task_definition_arn" {
  value = aws_ecs_task_definition.migrate.arn
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.this.name
}
