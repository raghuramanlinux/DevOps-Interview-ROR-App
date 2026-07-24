resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_db_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-db-subnet-group"
  })
}

# Master password is generated and stored by RDS in Secrets Manager (manage_master_user_password)
# instead of a static password living in tfvars or Terraform state in plaintext.
resource "aws_db_instance" "this" {
  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = var.engine_version

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_sg_id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period   = var.backup_retention_period
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project_name}-db-final-snapshot"

  apply_immediately          = true
  auto_minor_version_upgrade = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-db"
  })
}
