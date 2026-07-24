variable "project_name" {
  description = "Short name used as a prefix for all resource names"
  type        = string
  default     = "ror-app"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

# --- Networking ---

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_app_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "private_db_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "single_nat_gateway" {
  description = "One shared NAT gateway (cheaper) vs one per AZ (more resilient)"
  type        = bool
  default     = true
}

# --- Database ---

variable "db_engine_version" {
  type    = string
  default = "13.3"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage" {
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

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "db_skip_final_snapshot" {
  type    = bool
  default = true
}

# --- S3 ---

variable "s3_bucket_name" {
  description = "Globally-unique S3 bucket name for ActiveStorage uploads"
  type        = string
}

# --- Rails secrets ---

variable "rails_master_key" {
  description = "Contents of config/master.key from the forked repo (decrypts config/credentials.yml.enc). Do not commit the actual value."
  type        = string
  sensitive   = true
}

# --- ECS / containers ---

variable "image_tag" {
  description = "Image tag to deploy. CI pushes tags like sha-<gitsha>; defaults to latest for first apply."
  type        = string
  default     = "latest"
}

variable "task_cpu" {
  type    = string
  default = "512"
}

variable "task_memory" {
  type    = string
  default = "1024"
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

# --- GitHub Actions OIDC ---

variable "github_org" {
  description = "Your GitHub username/org that owns the fork"
  type        = string
}

variable "github_repo" {
  description = "Forked repo name"
  type        = string
  default     = "DevOps-Interview-ROR-App"
}

variable "create_github_oidc_provider" {
  description = "Set false if a token.actions.githubusercontent.com OIDC provider already exists in this AWS account"
  type        = bool
  default     = true
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "DevOps-Interview-ROR-App"
    ManagedBy = "terraform"
  }
}
