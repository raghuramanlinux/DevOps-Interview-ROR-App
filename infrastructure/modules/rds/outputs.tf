output "db_address" {
  value = aws_db_instance.this.address
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "db_username" {
  value = aws_db_instance.this.username
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN holding the auto-generated master password (json key: password)"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
