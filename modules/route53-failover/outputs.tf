output "health_check_id" {
  description = "ID of the Route 53 health check"
  value       = aws_route53_health_check.primary_region_check.id
}

output "dr_failover_sns_topic_arn" {
  description = "ARN of the SNS topic for DR failover notifications"
  value       = aws_sns_topic.dr_failover_notification.arn
}

output "dr_recovery_sns_topic_arn" {
  description = "ARN of the SNS topic for DR recovery notifications"
  value       = aws_sns_topic.dr_recovery_notification.arn
}

output "route53_zone_id" {
  description = "ID of the Route 53 zone used"
  value       = var.create_zone ? aws_route53_zone.primary[0].zone_id : var.hosted_zone_id
}

output "primary_dns_name" {
  description = "DNS name for the primary endpoint"
  value       = length(aws_route53_record.primary) > 0 ? aws_route53_record.primary[0].name : null
}