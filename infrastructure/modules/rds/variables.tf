variable "project_name" {
  type = string
}

variable "private_db_subnet_ids" {
  type = list(string)
}

variable "rds_sg_id" {
  type = string
}

variable "engine_version" {
  description = "Postgres engine version. README specifies 13.3; bump if AWS has deprecated that minor version in your region."
  type        = string
  default     = "13.3"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "rails"
}

variable "db_username" {
  type    = string
  default = "postgres"
}

variable "multi_az" {
  description = "Run a synchronous standby in a second AZ for failover. Recommended for production."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  description = "Set true for production to prevent accidental terraform destroy from deleting the DB."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Set false for production so a final snapshot is taken on destroy."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
