# Monitoring Module - Main Configuration

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project}-${var.environment}-dashboard"
  
  dashboard_body = <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/ECS", "CPUUtilization", "ServiceName", "${var.ecs_service_name}", "ClusterName", "${var.ecs_cluster_name}", { "stat": "Average" } ]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "ECS CPU Utilization"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/ECS", "MemoryUtilization", "ServiceName", "${var.ecs_service_name}", "ClusterName", "${var.ecs_cluster_name}", { "stat": "Average" } ]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "ECS Memory Utilization"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", "${var.alb_name}", { "stat": "Sum" } ]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "ALB Request Count"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "${var.alb_name}", { "stat": "Average" } ]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "ALB Response Time"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 12,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "${var.db_instance_id}", { "stat": "Average" } ]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "RDS CPU Utilization"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 12,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "${var.db_instance_id}", { "stat": "Average" } ]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "RDS Database Connections"
      }
    }
  ]
}
EOF
}

# CloudWatch Log Group for application
resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/application/${var.project}-${var.environment}"
  retention_in_days = 30

  tags = {
    Name        = "${var.project}-${var.environment}-app-log-group"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Prometheus container definition for ECS task
locals {
  prometheus_definition = {
    name      = "prometheus"
    image     = "prom/prometheus:latest"
    essential = true
    portMappings = [
      {
        containerPort = 9090
        hostPort      = 9090
        protocol      = "tcp"
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.prometheus.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "prometheus"
      }
    }
    mountPoints = [
      {
        sourceVolume  = "prometheus-config"
        containerPath = "/etc/prometheus"
      },
      {
        sourceVolume  = "prometheus-data"
        containerPath = "/prometheus"
      }
    ]
    memory = 512
    cpu    = 256
  }

  grafana_definition = {
    name      = "grafana"
    image     = "grafana/grafana:latest"
    essential = true
    portMappings = [
      {
        containerPort = 3000
        hostPort      = 3000
        protocol      = "tcp"
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.grafana.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "grafana"
      }
    }
    environment = [
      {
        name  = "GF_SECURITY_ADMIN_PASSWORD"
        value = var.grafana_password
      },
      {
        name  = "GF_SECURITY_ADMIN_USER"
        value = "admin"
      },
      {
        name  = "GF_USERS_ALLOW_SIGN_UP"
        value = "false"
      }
    ]
    mountPoints = [
      {
        sourceVolume  = "grafana-data"
        containerPath = "/var/lib/grafana"
      }
    ]
    memory = 512
    cpu    = 256
  }

  prometheus_container_definition = jsonencode([local.prometheus_definition])
  grafana_container_definition = jsonencode([local.grafana_definition])
  combined_container_definitions = jsonencode([local.prometheus_definition, local.grafana_definition])
}

# Prometheus Log Group
resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/aws/ecs/${var.project}-${var.environment}/prometheus"
  retention_in_days = 30

  tags = {
    Name        = "${var.project}-${var.environment}-prometheus-log-group"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Grafana Log Group
resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/aws/ecs/${var.project}-${var.environment}/grafana"
  retention_in_days = 30

  tags = {
    Name        = "${var.project}-${var.environment}-grafana-log-group"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Security group for monitoring services
resource "aws_security_group" "monitoring" {
  name        = "${var.project}-${var.environment}-monitoring-sg"
  description = "Security group for monitoring services"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [var.ecs_security_group]
  }

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [var.ecs_security_group]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-monitoring-sg"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Alarms for critical metrics with SNS notifications if alerting is enabled
resource "aws_sns_topic" "alarms" {
  count = var.alerting_enabled ? 1 : 0
  name  = "${var.project}-${var.environment}-alarms"

  tags = {
    Name        = "${var.project}-${var.environment}-alarms-topic"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# High CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  count               = var.alerting_enabled ? 1 : 0
  alarm_name          = "${var.project}-${var.environment}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_description = "This alarm monitors ECS CPU utilization"
  alarm_actions     = [aws_sns_topic.alarms[0].arn]
  ok_actions        = [aws_sns_topic.alarms[0].arn]

  tags = {
    Name        = "${var.project}-${var.environment}-cpu-high-alarm"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Database High CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "db_cpu_high" {
  count               = var.alerting_enabled && var.enable_db_alarms ? 1 : 0
  alarm_name          = "${var.project}-${var.environment}-db-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }

  alarm_description = "This alarm monitors RDS CPU utilization"
  alarm_actions     = [aws_sns_topic.alarms[0].arn]
  ok_actions        = [aws_sns_topic.alarms[0].arn]

  tags = {
    Name        = "${var.project}-${var.environment}-db-cpu-high-alarm"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Conditional creation of Grafana and Prometheus resources
resource "aws_ecs_task_definition" "monitoring" {
  count = var.create_grafana_dashboard ? 1 : 0
  
  family                   = "${var.project}-${var.environment}-monitoring"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.ecs_task_execution_role
  task_role_arn            = var.ecs_task_role
 
  container_definitions = var.create_prometheus ? local.combined_container_definitions : local.grafana_container_definition

  # Volume for Prometheus config
  dynamic "volume" {
    for_each = var.create_prometheus ? [1] : []
    content {
      name = "prometheus-config"
    }
  }

  # Volume for Prometheus data
  dynamic "volume" {
    for_each = var.create_prometheus ? [1] : []
    content {
      name = "prometheus-data"
      docker_volume_configuration {
        scope         = "shared"
        autoprovision = true
        driver        = "local"
      }
    }
  }

  # Volume for Grafana data
  volume {
    name = "grafana-data"
    docker_volume_configuration {
      scope         = "shared"
      autoprovision = true
      driver        = "local"
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-monitoring-task"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# ECS Service for monitoring
resource "aws_ecs_service" "monitoring" {
  count = var.create_grafana_dashboard ? 1 : 0
  
  name            = "${var.project}-${var.environment}-monitoring"
  cluster         = var.ecs_cluster_arn
  task_definition = aws_ecs_task_definition.monitoring[0].arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [aws_security_group.monitoring.id]
    assign_public_ip = false
  }

  tags = {
    Name        = "${var.project}-${var.environment}-monitoring-service"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Outputs
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