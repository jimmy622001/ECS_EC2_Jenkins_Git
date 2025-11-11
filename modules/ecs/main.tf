# ECS Module - Main Configuration

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = var.container_insights ? "enabled" : "disabled"
  }

  tags = {
    Name        = "${var.project}-${var.environment}-cluster"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Launch template for EC2 instances
resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.project}-${var.environment}-launch-template-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type
  key_name      = var.ssh_key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.ecs_security_group]
    delete_on_termination       = true
  }

  monitoring {
    enabled = true
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config
    echo ECS_ENABLE_SPOT_INSTANCE_DRAINING=true >> /etc/ecs/ecs.config
    yum install -y aws-cfn-bootstrap aws-cli jq
    /opt/aws/bin/cfn-signal -e $? --stack ${var.project}-${var.environment} --resource ECSAutoScalingGroup --region ${var.aws_region}
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${var.project}-${var.environment}-ecs-instance"
      Environment = var.environment
      Project     = var.project
      Terraform   = "true"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group for ECS
resource "aws_autoscaling_group" "ecs" {
  name                = "${var.project}-${var.environment}-ecs-asg"
  vpc_zone_identifier = var.private_subnets
  min_size            = var.min_capacity
  max_size            = var.max_capacity
  desired_capacity    = var.min_capacity
  
  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project}-${var.environment}-ecs-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
  
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

# ECS Capacity Provider
resource "aws_ecs_capacity_provider" "main" {
  name = "${var.project}-${var.environment}-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn
    
    managed_scaling {
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

# Associate capacity provider with cluster
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 1
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group]
  subnets            = var.public_subnets

  enable_deletion_protection = var.environment == "prod" ? true : false

  tags = {
    Name        = "${var.project}-${var.environment}-alb"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# ALB Target Group
resource "aws_lb_target_group" "app" {
  name                 = "${var.project}-${var.environment}-tg"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 30
  target_type          = "instance"
  
  health_check {
    path                = var.health_check_path
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-299"
  }

  tags = {
    Name        = "${var.project}-${var.environment}-tg"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ALB Listener (HTTPS)
resource "aws_lb_listener" "https" {
  depends_on = [aws_acm_certificate_validation.cert]
  
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.create_dummy_cert ? aws_acm_certificate.cert[0].arn : var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ALB Listener (HTTP to HTTPS redirect)
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project}-${var.environment}-task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.ecs_task_execution_role
  task_role_arn            = var.ecs_task_role
  cpu                      = var.task_cpu
  memory                   = var.task_memory

  container_definitions = jsonencode([
    {
      name      = "${var.project}-${var.environment}-container"
      image     = "${var.container_image}:latest"
      essential = true
      
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = 0 # Dynamic port mapping
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      ]
      
      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:/${var.project}/${var.environment}/database:url::"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name        = "${var.project}-${var.environment}-task"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# ECS Service
resource "aws_ecs_service" "app" {
  name                               = "${var.project}-${var.environment}-service"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.app.arn
  desired_count                      = var.desired_task_count
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60
  launch_type                        = "EC2"

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "${var.project}-${var.environment}-container"
    container_port   = var.container_port
  }

  deployment_controller {
    type = "ECS"
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [aws_lb_listener.https]

  tags = {
    Name        = "${var.project}-${var.environment}-service"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Auto Scaling for the ECS Service
resource "aws_appautoscaling_target" "ecs_service" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Scale up policy (CPU)
resource "aws_appautoscaling_policy" "ecs_cpu_policy_scale_up" {
  name               = "${var.project}-${var.environment}-scale-up-cpu"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

# Scale down policy (CPU)
resource "aws_appautoscaling_policy" "ecs_cpu_policy_scale_down" {
  name               = "${var.project}-${var.environment}-scale-down-cpu"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}

# CloudWatch Alarms for Auto Scaling
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.project}-${var.environment}-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 75

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_description = "This metric monitors ECS CPU utilization for scaling up"
  alarm_actions     = [aws_appautoscaling_policy.ecs_cpu_policy_scale_up.arn]

  tags = {
    Name        = "${var.project}-${var.environment}-cpu-high-alarm"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_low" {
  alarm_name          = "${var.project}-${var.environment}-cpu-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 30

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_description = "This metric monitors ECS CPU utilization for scaling down"
  alarm_actions     = [aws_appautoscaling_policy.ecs_cpu_policy_scale_down.arn]

  tags = {
    Name        = "${var.project}-${var.environment}-cpu-low-alarm"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project}-${var.environment}"
  retention_in_days = 30

  tags = {
    Name        = "${var.project}-${var.environment}-log-group"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# IAM Role for EC2 instances
resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.project}-${var.environment}-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-ecs-instance-role"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }
}

# Attach ECS instance role policy
resource "aws_iam_role_policy_attachment" "ecs_instance_role" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# Instance profile for EC2 instances
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${var.project}-${var.environment}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

# ACM Certificate (if creating a dummy cert)
resource "aws_acm_certificate" "cert" {
  count             = var.create_dummy_cert ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = {
    Name        = "${var.project}-${var.environment}-cert"
    Environment = var.environment
    Project     = var.project
    Terraform   = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Certificate validation (dummy logic for the module to work)
resource "aws_acm_certificate_validation" "cert" {
  count                   = var.create_dummy_cert ? 1 : 0
  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = ["dummy.${var.domain_name}"]
}

# Latest Amazon Linux 2 ECS-optimized AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Outputs
output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the ALB"
  value       = aws_lb.main.arn
}

output "alb_zone_id" {
  description = "Zone ID of the ALB"
  value       = aws_lb.main.zone_id
}