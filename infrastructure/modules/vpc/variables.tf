variable "project_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_app_subnet_cidrs" {
  type = list(string)
}

variable "private_db_subnet_cidrs" {
  type = list(string)
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway instead of one per AZ. Cheaper, less HA."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
