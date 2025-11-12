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

output "db_instance_arn" {
  description = "ARN of the database instance"
  value       = aws_db_instance.main.arn
}

output "db_replica_instance_id" {
  description = "ID of the DR database replica instance"
  value       = var.create_dr_read_replica && var.environment == "prod" ? aws_db_instance.dr_replica[0].id : null
}

output "db_replica_endpoint" {
  description = "Connection endpoint of the DR database replica"
  value       = var.create_dr_read_replica && var.environment == "prod" ? aws_db_instance.dr_replica[0].endpoint : null
}

output "replication_sns_topic_arn" {
  description = "ARN of the SNS topic for replication failures"
  value       = var.replication_sns_topic_arn == "" && (var.enable_cross_region_replica || var.create_dr_read_replica) && var.environment == "prod" ? aws_sns_topic.replication_failures[0].arn : var.replication_sns_topic_arn
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