variable "project_name" {
  type = string
}

variable "repository_names" {
  description = "Short names (e.g. [\"rails\", \"nginx\"]) -> repos named <project_name>-<name>"
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
