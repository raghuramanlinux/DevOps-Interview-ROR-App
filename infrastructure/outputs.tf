output "application_url" {
  description = "Open this in a browser once tasks are healthy"
  value       = "http://${module.alb.alb_dns_name}"
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

output "ecs_migrate_task_definition_arn" {
  value = module.ecs.migrate_task_definition_arn
}

output "rds_address" {
  value = module.rds.db_address
}

output "s3_bucket_name" {
  value = module.s3.bucket_id
}

output "private_app_subnet_ids" {
  description = "Needed for `aws ecs run-task` (--network-configuration) from CI or CLI"
  value       = module.vpc.private_app_subnet_ids
}

output "ecs_tasks_security_group_id" {
  description = "Needed for `aws ecs run-task` (--network-configuration) from CI or CLI"
  value       = module.security_groups.ecs_tasks_sg_id
}

output "github_actions_deploy_role_arn" {
  description = "Set as the AWS_ROLE_ARN repo variable / used by aws-actions/configure-aws-credentials in .github/workflows/deploy.yml"
  value       = module.iam.github_actions_deploy_role_arn
}

output "github_actions_setup_summary" {
  description = "Values to add as GitHub repo variables (Settings > Secrets and variables > Actions > Variables) for the CI/CD workflow"
  value = {
    AWS_REGION              = var.region
    AWS_ROLE_ARN            = module.iam.github_actions_deploy_role_arn
    ECR_RAILS_REPOSITORY    = module.ecr.repository_urls["rails"]
    ECR_NGINX_REPOSITORY    = module.ecr.repository_urls["nginx"]
    ECS_CLUSTER             = module.ecs.cluster_name
    ECS_SERVICE             = module.ecs.service_name
    ECS_APP_TASK_FAMILY     = local.app_task_family
    ECS_MIGRATE_TASK_FAMILY = local.migrate_task_family
    ECS_SUBNETS             = join(",", module.vpc.private_app_subnet_ids)
    ECS_SECURITY_GROUP      = module.security_groups.ecs_tasks_sg_id
  }
}
