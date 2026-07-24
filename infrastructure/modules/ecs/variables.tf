variable "project_name" {
  type = string
}

variable "region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "service_name" {
  type = string
}

variable "app_task_family" {
  type = string
}

variable "migrate_task_family" {
  type = string
}

variable "private_app_subnet_ids" {
  type = list(string)
}

variable "ecs_tasks_sg_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "rails_image" {
  description = "ECR repository URL for the rails_app image (no tag)"
  type        = string
}

variable "nginx_image" {
  description = "ECR repository URL for the nginx image (no tag)"
  type        = string
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "task_cpu" {
  type    = string
  default = "512"
}

variable "task_memory" {
  type    = string
  default = "1024"
}

variable "migrate_task_cpu" {
  type    = string
  default = "256"
}

variable "migrate_task_memory" {
  type    = string
  default = "512"
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "min_capacity" {
  type    = number
  default = 2
}

variable "max_capacity" {
  type    = number
  default = 4
}

variable "log_retention_days" {
  type    = number
  default = 14
}

# --- Application environment ---

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_address" {
  type = string
}

variable "db_port" {
  type = string
}

variable "db_password_secret_arn" {
  description = "Secrets Manager ARN of the RDS-managed master password (json)"
  type        = string
}

variable "rails_master_key_secret_arn" {
  description = "Secrets Manager ARN holding the Rails master key (plain string)"
  type        = string
}

variable "s3_bucket_name" {
  type = string
}

variable "s3_region_name" {
  type = string
}

variable "lb_endpoint" {
  description = "ALB DNS name, without protocol, for Rails config.hosts and LB_ENDPOINT"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR, allowlisted in Rails config.hosts so ALB IP-based health check requests aren't 403'd"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
