# Security Module - Main Configuration

# AWS WAF WebACL
resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project}-${var.environment}-waf"
  description = "WAF for ${var.project} ${var.environment} environment"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # AWS Managed Rules - Core rule set
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Known bad inputs
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - SQL injection
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 30

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesSQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # IP rate limiting - Prevent brute force
  rule {
    name     = "RateLimit"
    priority = 40

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }

  # Custom rule - Block specific countries if configured
  dynamic "rule" {
    for_each = length(var.blocked_countries) > 0 ? [1] : []
    content {
      name     = "BlockCountries"
      priority = 50

      action {
        block {}
      }

      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "BlockCountries"
        sampled_requests_enabled   = true
      }
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-waf"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project}-${var.environment}-waf"
    sampled_requests_enabled   = true
  }
}

# Associate WAF with ALB if enabled
resource "aws_wafv2_web_acl_association" "alb" {
  count        = var.enable_waf_association ? 1 : 0
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# SecurityHub Enablement
resource "aws_securityhub_account" "main" {
  count = var.enable_security_hub ? 1 : 0
}

# Enable CIS AWS Foundations Benchmark in Security Hub
resource "aws_securityhub_standards_subscription" "cis_aws_foundations" {
  count         = var.enable_security_hub ? 1 : 0
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/cis-aws-foundations-benchmark/v/1.2.0"
}

# Enable AWS Foundational Security Best Practices
resource "aws_securityhub_standards_subscription" "aws_best_practices" {
  count         = var.enable_security_hub ? 1 : 0
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

# GuardDuty Enablement (if enabled)
resource "aws_guardduty_detector" "main" {
  count                = var.enable_guardduty ? 1 : 0
  enable               = true
  finding_publishing_frequency = "ONE_HOUR"

  tags = {
    Name        = "${var.project}-${var.environment}-guardduty"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Config Service for compliance monitoring (if enabled)
resource "aws_config_configuration_recorder" "main" {
  count    = var.enable_config ? 1 : 0
  name     = "${var.project}-${var.environment}-config"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = var.environment == "prod" ? true : false
  }
}

resource "aws_config_delivery_channel" "main" {
  count          = var.enable_config ? 1 : 0
  name           = "${var.project}-${var.environment}-config-channel"
  s3_bucket_name = aws_s3_bucket.config[0].bucket
  depends_on     = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  count      = var.enable_config ? 1 : 0
  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}

# Config Service IAM Role
resource "aws_iam_role" "config" {
  count = var.enable_config ? 1 : 0
  name  = "${var.project}-${var.environment}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-config-role"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Attach AWS managed policy for Config
resource "aws_iam_role_policy_attachment" "config" {
  count      = var.enable_config ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# S3 bucket for AWS Config logs
resource "aws_s3_bucket" "config" {
  count  = var.enable_config ? 1 : 0
  bucket = "${var.project}-${var.environment}-config-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project}-${var.environment}-config-logs"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

resource "aws_s3_bucket_public_access_block" "config" {
  count  = var.enable_config ? 1 : 0
  bucket = aws_s3_bucket.config[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  count  = var.enable_config ? 1 : 0
  bucket = aws_s3_bucket.config[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "config" {
  count  = var.enable_config ? 1 : 0
  bucket = aws_s3_bucket.config[0].id

  rule {
    id     = "log-retention"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 365
    }
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Outputs
output "waf_web_acl_id" {
  description = "ID of the WAF WebACL"
  value       = aws_wafv2_web_acl.main.id
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF WebACL"
  value       = aws_wafv2_web_acl.main.arn
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : ""
}

output "config_recorder_id" {
  description = "ID of the Config recorder"
  value       = var.enable_config ? aws_config_configuration_recorder.main[0].id : ""
}