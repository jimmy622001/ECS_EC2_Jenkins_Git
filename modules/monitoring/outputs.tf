# Monitoring Module - Outputs

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "prometheus_log_group_name" {
  description = "Name of the Prometheus log group"
  value       = aws_cloudwatch_log_group.prometheus.name
}

output "grafana_log_group_name" {
  description = "Name of the Grafana log group"
  value       = aws_cloudwatch_log_group.grafana.name
}

output "monitoring_security_group_id" {
  description = "ID of the monitoring security group"
  value       = aws_security_group.monitoring.id
}

output "alarm_sns_topic_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = var.alerting_enabled ? aws_sns_topic.alarms[0].arn : ""
}