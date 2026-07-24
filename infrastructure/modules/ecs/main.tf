resource "aws_ecs_cluster" "this" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.tags, {
    Name = var.cluster_name
  })
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

locals {
  rails_env_base = [
    { name = "RAILS_ENV", value = "production" },
    { name = "RAILS_LOG_TO_STDOUT", value = "true" },
    { name = "RAILS_SERVE_STATIC_FILES", value = "true" },
    { name = "RDS_DB_NAME", value = var.db_name },
    { name = "RDS_USERNAME", value = var.db_username },
    { name = "RDS_HOSTNAME", value = var.db_address },
    { name = "RDS_PORT", value = var.db_port },
    { name = "S3_BUCKET_NAME", value = var.s3_bucket_name },
    { name = "S3_REGION_NAME", value = var.s3_region_name },
    { name = "LB_ENDPOINT", value = var.lb_endpoint },
    { name = "VPC_CIDR", value = var.vpc_cidr },
  ]

  rails_secrets = [
    { name = "RDS_PASSWORD", valueFrom = "${var.db_password_secret_arn}:password::" },
    { name = "RAILS_MASTER_KEY", valueFrom = var.rails_master_key_secret_arn },
  ]

  rails_log_config = {
    logDriver = "awslogs"
    options = {
      "awslogs-group"         = aws_cloudwatch_log_group.this.name
      "awslogs-region"        = var.region
      "awslogs-stream-prefix" = "rails"
    }
  }

  nginx_log_config = {
    logDriver = "awslogs"
    options = {
      "awslogs-group"         = aws_cloudwatch_log_group.this.name
      "awslogs-region"        = var.region
      "awslogs-stream-prefix" = "nginx"
    }
  }
}

# =========================================================================
# "app" task definition: rails_app + nginx, run by the long-lived service.
# Migrations are NOT run here (RUN_DB_MIGRATIONS=false) to avoid every
# replica racing to migrate the schema concurrently on deploy/scale-out.
# =========================================================================

resource "aws_ecs_task_definition" "app" {
  family                   = var.app_task_family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "rails_app"
      image     = "${var.rails_image}:${var.image_tag}"
      essential = true
      portMappings = [
        { containerPort = 3000, protocol = "tcp" }
      ]
      environment = concat(local.rails_env_base, [
        { name = "RUN_DB_MIGRATIONS", value = "false" }
      ])
      secrets          = local.rails_secrets
      logConfiguration = local.rails_log_config
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/ || exit 1"]
        interval    = 15
        timeout     = 5
        retries     = 3
        startPeriod = 45
      }
    },
    {
      name      = "nginx"
      image     = "${var.nginx_image}:${var.image_tag}"
      essential = true
      portMappings = [
        { containerPort = 80, protocol = "tcp" }
      ]
      # The image defaults RAILS_UPSTREAM=rails_app (docker-compose bridge
      # network DNS name). In Fargate awsvpc mode, sibling containers in the
      # same task share one network namespace and talk over localhost - the
      # container-name DNS lookup nginx does otherwise fails with
      # "host not found in upstream", which kills the whole task since both
      # containers are essential.
      environment = [
        { name = "RAILS_UPSTREAM", value = "127.0.0.1" }
      ]
      dependsOn = [
        { containerName = "rails_app", condition = "HEALTHY" }
      ]
      logConfiguration = local.nginx_log_config
    }
  ])

  tags = var.tags
}

# =========================================================================
# "migrate" task definition: one-shot, run manually / from CI before a
# deploy (`aws ecs run-task ...`). Runs db:create/schema:load/migrate then
# exits; never receives traffic.
# =========================================================================

resource "aws_ecs_task_definition" "migrate" {
  family                   = var.migrate_task_family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.migrate_task_cpu
  memory                   = var.migrate_task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "rails_app"
      image     = "${var.rails_image}:${var.image_tag}"
      essential = true
      command   = ["echo", "migration complete"]
      environment = concat(local.rails_env_base, [
        { name = "RUN_DB_MIGRATIONS", value = "true" },
        # db:schema:load is classified as a destructive rake task and Rails
        # refuses to run it against RAILS_ENV=production (even on a fresh,
        # empty database) unless this is set. Scoped to the one-shot migrate
        # task only - the long-running service tasks never set it.
        { name = "DISABLE_DATABASE_ENVIRONMENT_CHECK", value = "1" }
      ])
      secrets          = local.rails_secrets
      logConfiguration = local.rails_log_config
    }
  ])

  tags = var.tags
}

resource "aws_ecs_service" "app" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [var.ecs_tasks_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "nginx"
    container_port   = 80
  }

  health_check_grace_period_seconds  = 90
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  enable_execute_command             = true

  # Without this, a deployment that can never reach steady state (bad image
  # tag, crashing container, etc.) retries indefinitely instead of rolling
  # back - which is exactly what happened with the very first deployment
  # here (task-def :1, referencing an image tag that had never been pushed).
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # CI (GitHub Actions) registers new task definition revisions and calls
  # update-service directly after the initial bootstrap - Terraform only
  # owns the *shape* of the task definition, not which revision is live.
  # Without this, every `terraform apply` snaps the service back to
  # whichever revision Terraform itself last created, undoing CI deploys.
  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = var.tags
}

resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.project_name}-cpu-target-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
