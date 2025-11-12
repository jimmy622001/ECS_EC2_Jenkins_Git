# Project variables
variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# Network variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
}

variable "cache_subnet_cidrs" {
  description = "CIDR blocks for ElastiCache subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access"
  type        = string
}

# EC2 configuration variables
variable "instance_type" {
  description = "EC2 instance type for ECS cluster"
  type        = string
}

variable "ssh_key_name" {
  description = "SSH key name for EC2 instances"
  type        = string
}

variable "min_capacity" {
  description = "Minimum number of EC2 instances"
  type        = number
}

variable "max_capacity" {
  description = "Maximum number of EC2 instances"
  type        = number
}

# ECS variables
variable "container_insights" {
  description = "Enable container insights for ECS cluster"
  type        = bool
}

variable "desired_task_count" {
  description = "Desired number of tasks for ECS service"
  type        = number
}

variable "container_image" {
  description = "Container image name without tag"
  type        = string
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
}

variable "health_check_path" {
  description = "Path for health check"
  type        = string
}

variable "task_cpu" {
  description = "CPU units for the task"
  type        = number
}

variable "task_memory" {
  description = "Memory for the task in MiB"
  type        = number
}

# Database variables
variable "db_instance_class" {
  description = "Database instance class"
  type        = string
}

variable "db_allocated_storage" {
  description = "Allocated storage for database in GB"
  type        = number
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for database in GB"
  type        = number
}

variable "db_engine" {
  description = "Database engine (postgres or mysql)"
  type        = string
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
}

variable "db_name" {
  description = "Name of the database"
  type        = string
}

variable "db_username" {
  description = "Username for the database"
  type        = string
}

variable "db_password" {
  description = "Password for the database (leave empty to generate random)"
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "Port for the database"
  type        = number
}

variable "db_multi_az" {
  description = "Enable multi-AZ for database"
  type        = bool
}

variable "enable_performance_insights" {
  description = "Enable Performance Insights"
  type        = bool
}

# Database parameters
variable "postgres_parameters" {
  description = "List of PostgreSQL parameters"
  type = list(object({
    name  = string
    value = string
  }))
}

variable "mysql_parameters" {
  description = "List of MySQL parameters"
  type = list(object({
    name  = string
    value = string
  }))
}

# Monitoring variables
variable "create_grafana_dashboard" {
  description = "Create Grafana dashboard"
  type        = bool
}

variable "create_prometheus" {
  description = "Create Prometheus instance"
  type        = bool
}

variable "alerting_enabled" {
  description = "Enable CloudWatch alarms with SNS notifications"
  type        = bool
}

variable "grafana_password" {
  description = "Password for Grafana admin user"
  type        = string
  sensitive   = true
}

# CI/CD variables
variable "jenkins_instance_type" {
  description = "Jenkins instance type"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository for CI/CD integration"
  type        = string
}

variable "codedeploy_group_name" {
  description = "CodeDeploy deployment group name"
  type        = string
}

# Security variables
variable "waf_rate_limit" {
  description = "Rate limit for IP-based throttling (requests/5min)"
  type        = number
}

variable "waf_blocked_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2 codes)"
  type        = list(string)
}

variable "enable_security_hub" {
  description = "Enable AWS Security Hub"
  type        = bool
}

variable "enable_guardduty" {
  description = "Enable AWS GuardDuty"
  type        = bool
}

variable "enable_config" {
  description = "Enable AWS Config"
  type        = bool
}

# SSL/TLS variables
variable "domain_name" {
  description = "Domain name for ALB"
  type        = string
}

variable "create_dummy_cert" {
  description = "Create dummy certificate for HTTPS (set to false in production)"
  type        = bool
}

variable "acm_certificate_arn" {
  description = "ARN of an existing ACM certificate (if not creating a dummy cert)"
  type        = string
}

# Deployment flags
variable "deploy_network" {
  description = "Deploy network module"
  type        = bool
}

variable "deploy_iam" {
  description = "Deploy IAM module"
  type        = bool
}

variable "deploy_ecs" {
  description = "Deploy ECS module"
  type        = bool
}

variable "deploy_database" {
  description = "Deploy database module"
  type        = bool
}

variable "deploy_cicd" {
  description = "Deploy CI/CD module"
  type        = bool
}

variable "deploy_monitoring" {
  description = "Deploy monitoring module"
  type        = bool
}

variable "deploy_security" {
  description = "Deploy security module"
  type        = bool
}

# Variables for pre-existing resources (when not creating new ones)
variable "vpc_id" {
  description = "Existing VPC ID (when deploy_network = false)"
  type        = string
}

variable "private_subnets" {
  description = "Existing private subnet IDs (when deploy_network = false)"
  type        = list(string)
}

variable "public_subnets" {
  description = "Existing public subnet IDs (when deploy_network = false)"
  type        = list(string)
}

variable "database_subnets" {
  description = "Existing database subnet IDs (when deploy_network = false)"
  type        = list(string)
}

variable "alb_security_group" {
  description = "Existing ALB security group ID (when deploy_network = false)"
  type        = string
}

variable "ecs_security_group" {
  description = "Existing ECS security group ID (when deploy_network = false)"
  type        = string
}

variable "db_security_group" {
  description = "Existing database security group ID (when deploy_network = false)"
  type        = string
}

variable "jenkins_security_group" {
  description = "Existing Jenkins security group ID (when deploy_network = false)"
  type        = string
}

variable "ecs_task_execution_role" {
  description = "Existing ECS task execution role ARN (when deploy_iam = false)"
  type        = string
}

variable "ecs_task_role" {
  description = "Existing ECS task role ARN (when deploy_iam = false)"
  type        = string
}

variable "jenkins_instance_profile" {
  description = "Existing Jenkins instance profile name (when deploy_iam = false)"
  type        = string
}

variable "codedeploy_role" {
  description = "Existing CodeDeploy role ARN (when deploy_iam = false)"
  type        = string
}

variable "ecs_cluster_arn" {
  description = "Existing ECS cluster ARN (when deploy_ecs = false)"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Existing ECS cluster name (when deploy_ecs = false)"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name"
  type        = string
}

variable "alb_arn" {
  description = "Existing ALB ARN (when deploy_ecs = false)"
  type        = string
}

variable "alb_name" {
  description = "Name of the ALB for CloudWatch dashboard"
  type        = string
}

variable "alb_listener_arn" {
  description = "ARN of the ALB listener"
  type        = string
}

variable "alb_target_group_name_blue" {
  description = "Name of the blue target group"
  type        = string
}

variable "alb_target_group_name_green" {
  description = "Name of the green target group"
  type        = string
}

variable "db_instance_id" {
  description = "Existing RDS instance ID (when deploy_database = false)"
  type        = string
}

# ElastiCache variables
variable "enable_elasticache" {
  description = "Enable ElastiCache deployment"
  type        = bool
}

variable "cache_node_type" {
  description = "ElastiCache node type"
  type        = string
}

variable "cache_nodes" {
  description = "Number of Redis cache nodes"
  type        = number
}

variable "cache_security_group" {
  description = "Existing ElastiCache security group ID (when deploy_network = false)"
  type        = string
}