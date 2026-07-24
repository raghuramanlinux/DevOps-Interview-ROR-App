data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  cluster_name         = "${var.project_name}-cluster"
  service_name         = "${var.project_name}-service"
  app_task_family      = "${var.project_name}-app"
  migrate_task_family  = "${var.project_name}-migrate"
}

module "vpc" {
  source = "./modules/vpc"

  project_name              = var.project_name
  vpc_cidr                  = var.vpc_cidr
  azs                       = var.azs
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs  = var.private_app_subnet_cidrs
  private_db_subnet_cidrs   = var.private_db_subnet_cidrs
  single_nat_gateway        = var.single_nat_gateway
  tags                      = var.tags
}

module "ecr" {
  source = "./modules/ecr"

  project_name     = var.project_name
  repository_names = ["rails", "nginx"]
  tags             = var.tags
}

module "security_groups" {
  source = "./modules/security_groups"

  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  tags         = var.tags
}

module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
  health_check_path = "/"
  tags              = var.tags
}

module "s3" {
  source = "./modules/s3"

  bucket_name = var.s3_bucket_name
  tags        = var.tags
}

module "rds" {
  source = "./modules/rds"

  project_name             = var.project_name
  private_db_subnet_ids    = module.vpc.private_db_subnet_ids
  rds_sg_id                = module.security_groups.rds_sg_id
  engine_version            = var.db_engine_version
  instance_class            = var.db_instance_class
  allocated_storage         = var.db_allocated_storage
  db_name                   = var.db_name
  db_username               = var.db_username
  multi_az                  = var.db_multi_az
  deletion_protection       = var.db_deletion_protection
  skip_final_snapshot       = var.db_skip_final_snapshot
  tags                      = var.tags
}

# Rails' secret_key_base is derived from this key + config/credentials.yml.enc
# (both already committed in the forked repo). Stored in Secrets Manager so
# it's injected at runtime rather than relying solely on the value baked
# into the image.
resource "aws_secretsmanager_secret" "rails_master_key" {
  name = "${var.project_name}/rails-master-key"
  tags = var.tags

  # Demo/interview convenience: a destroy+recreate cycle would otherwise fail
  # with "already scheduled for deletion" during the default 30-day recovery
  # window. Keep the default (or a positive value) for production.
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "rails_master_key" {
  secret_id     = aws_secretsmanager_secret.rails_master_key.id
  secret_string = var.rails_master_key
}

module "iam" {
  source = "./modules/iam"

  project_name          = var.project_name
  region                = var.region
  account_id            = local.account_id
  s3_bucket_arn         = module.s3.bucket_arn
  secrets_manager_arns  = [module.rds.master_user_secret_arn, aws_secretsmanager_secret.rails_master_key.arn]
  ecs_cluster_name      = local.cluster_name
  ecs_service_name      = local.service_name
  app_task_family       = local.app_task_family
  migrate_task_family   = local.migrate_task_family
  github_org            = var.github_org
  github_repo           = var.github_repo
  create_github_oidc_provider = var.create_github_oidc_provider
  tags                  = var.tags
}

module "ecs" {
  source = "./modules/ecs"

  project_name         = var.project_name
  region               = var.region
  cluster_name         = local.cluster_name
  service_name         = local.service_name
  app_task_family      = local.app_task_family
  migrate_task_family  = local.migrate_task_family

  private_app_subnet_ids = module.vpc.private_app_subnet_ids
  ecs_tasks_sg_id         = module.security_groups.ecs_tasks_sg_id
  target_group_arn        = module.alb.target_group_arn

  execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn       = module.iam.ecs_task_role_arn

  rails_image = module.ecr.repository_urls["rails"]
  nginx_image = module.ecr.repository_urls["nginx"]
  image_tag   = var.image_tag

  task_cpu      = var.task_cpu
  task_memory   = var.task_memory
  desired_count = var.desired_count
  min_capacity  = var.min_capacity
  max_capacity  = var.max_capacity

  db_name                     = module.rds.db_name
  db_username                 = module.rds.db_username
  db_address                  = module.rds.db_address
  db_port                     = tostring(module.rds.db_port)
  db_password_secret_arn      = module.rds.master_user_secret_arn
  rails_master_key_secret_arn = aws_secretsmanager_secret.rails_master_key.arn

  s3_bucket_name = module.s3.bucket_id
  s3_region_name = var.region
  lb_endpoint    = module.alb.alb_dns_name

  tags = var.tags
}
