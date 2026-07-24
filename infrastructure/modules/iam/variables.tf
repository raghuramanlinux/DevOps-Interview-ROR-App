variable "project_name" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "s3_bucket_arn" {
  type = string
}

variable "secrets_manager_arns" {
  description = "Secrets the ECS task execution role may read to inject as container secrets (DB password, Rails master key)"
  type        = list(string)
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "app_task_family" {
  type = string
}

variable "migrate_task_family" {
  type = string
}

variable "github_org" {
  description = "GitHub org/user that owns the forked repo, for OIDC trust scoping"
  type        = string
}

variable "github_repo" {
  description = "Forked repo name, for OIDC trust scoping"
  type        = string
}

variable "create_github_oidc_provider" {
  description = "Set false if a token.actions.githubusercontent.com OIDC provider already exists in this AWS account"
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
