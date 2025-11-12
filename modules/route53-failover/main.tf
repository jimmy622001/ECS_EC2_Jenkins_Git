terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_route53_health_check" "primary_region_check" {
  fqdn              = var.primary_endpoint
  port              = 443
  type              = "HTTPS"
  resource_path     = var.health_check_path
  failure_threshold = 3
  request_interval  = 30
  
  tags = merge(
    {
      Name = "${var.name_prefix}-primary-health-check"
    },
    var.tags
  )
}

resource "aws_cloudwatch_metric_alarm" "primary_region_health_alarm" {
  alarm_name          = "${var.name_prefix}-primary-region-health-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "This metric monitors the health of the primary region"
  
  dimensions = {
    HealthCheckId = aws_route53_health_check.primary_region_check.id
  }
  
  alarm_actions = [aws_sns_topic.dr_failover_notification.arn]
  ok_actions    = [aws_sns_topic.dr_recovery_notification.arn]
}

resource "aws_sns_topic" "dr_failover_notification" {
  name = "${var.name_prefix}-dr-failover-notification"
  
  tags = var.tags
}

resource "aws_sns_topic" "dr_recovery_notification" {
  name = "${var.name_prefix}-dr-recovery-notification"
  
  tags = var.tags
}

# Create the Route53 hosted zone if it doesn't exist
resource "aws_route53_zone" "primary" {
  count = var.create_zone ? 1 : 0
  
  name = var.domain_name
  
  tags = merge(
    {
      Name = "${var.name_prefix}-hosted-zone"
    },
    var.tags
  )
}

# Set up DNS failover records
resource "aws_route53_record" "primary" {
  count           = var.create_zone || var.hosted_zone_id != "" ? 1 : 0
  zone_id         = var.create_zone ? aws_route53_zone.primary[0].zone_id : var.hosted_zone_id
  name            = var.domain_name
  type            = "A"
  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.primary_region_check.id
  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = var.primary_endpoint
    zone_id                = var.primary_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "secondary" {
  count           = var.create_zone || var.hosted_zone_id != "" ? 1 : 0
  zone_id        = var.create_zone ? aws_route53_zone.primary[0].zone_id : var.hosted_zone_id
  name           = var.domain_name
  type           = "A"
  set_identifier = "secondary"
  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = var.secondary_endpoint
    zone_id                = var.secondary_zone_id
    evaluate_target_health = true
  }
}

# Setup SNS subscription to Lambda if specified
resource "aws_sns_topic_subscription" "lambda_subscription" {
  count     = var.create_lambda_integration ? 1 : 0
  topic_arn = aws_sns_topic.dr_failover_notification.arn
  protocol  = "lambda"
  endpoint  = var.lambda_arn
}

resource "aws_lambda_permission" "allow_sns" {
  count         = var.create_lambda_integration ? 1 : 0
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.dr_failover_notification.arn
}