output "lambda_arn" {
  description = "ARN of the DR scale-up Lambda function"
  value       = aws_lambda_function.dr_scale_up.arn
}

output "lambda_name" {
  description = "Name of the DR scale-up Lambda function"
  value       = aws_lambda_function.dr_scale_up.function_name
}

output "cloudwatch_event_rule_arn" {
  description = "ARN of the CloudWatch Event Rule for DR failover"
  value       = length(aws_cloudwatch_event_rule.dr_failover_event) > 0 ? aws_cloudwatch_event_rule.dr_failover_event[0].arn : ""
}

output "monthly_test_rule_arn" {
  description = "ARN of the CloudWatch Event Rule for monthly DR testing"
  value       = aws_cloudwatch_event_rule.monthly_dr_test.arn
}