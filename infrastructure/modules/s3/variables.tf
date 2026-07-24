variable "bucket_name" {
  description = "Globally-unique S3 bucket name (e.g. <project_name>-<account_id>-storage)"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
