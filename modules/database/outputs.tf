# Database Module - Outputs

output "db_instance_id" {
  description = "ID of the RDS instance"
  value       = aws_db_instance.main.id
}

output "db_instance_address" {
  description = "Address of the RDS instance"
  value       = aws_db_instance.main.address
}

output "db_instance_port" {
  description = "Port of the RDS instance"
  value       = aws_db_instance.main.port
}

output "db_instance_name" {
  description = "Name of the database"
  value       = var.db_name
}

output "db_secret_arn" {
  description = "ARN of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

# RDS Proxy outputs - commented out until proxy is enabled
# Uncomment these when enabling the RDS Proxy resources

/*
output "db_proxy_endpoint" {
  description = "Endpoint of the RDS Proxy"
  value       = aws_db_proxy.main.endpoint
}

output "db_proxy_arn" {
  description = "ARN of the RDS Proxy"
  value       = aws_db_proxy.main.arn
}

output "db_proxy_target_endpoint" {
  description = "Connection endpoint for the database proxy"
  value       = "${var.db_engine}://${var.db_username}:${sensitive(var.db_password == "" ? random_password.db_password[0].result : var.db_password)}@${aws_db_proxy.main.endpoint}:${aws_db_instance.main.port}/${var.db_name}"
  sensitive   = true
}
*/