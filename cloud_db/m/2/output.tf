output "db_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = aws_db_instance.mysql.endpoint
}

output "db_username" {
  description = "The username to connect to the RDS instance"
  value       = aws_db_instance.mysql.username
}

output "db_password" {
  description = "The password to connect to the RDS instance"
  value       = random_password.db_password.result
  sensitive   = true
}

