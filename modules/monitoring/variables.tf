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
variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnets" {
  description = "IDs of the private subnets"
  type        = list(string)
}

variable "public_subnets" {
  description = "IDs of the public subnets"
  type        = list(string)
}

variable "ecs_security_group" {
  description = "ID of the ECS security group"
  type        = string
}

# CloudWatch dashboard variables
variable "alb_name" {
  description = "Name of the ALB for CloudWatch dashboard"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "db_instance_id" {
  description = "ID of the RDS instance"
  type        = string
}

# Monitoring options
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

variable "enable_db_alarms" {
  description = "Enable database-related CloudWatch alarms"
  type        = bool
}

# Grafana configuration
variable "grafana_password" {
  description = "Password for Grafana admin user"
  type        = string
  sensitive   = true
}

# ECS variables
variable "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  type        = string
}

variable "ecs_task_execution_role" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "ecs_task_role" {
  description = "ARN of the ECS task role"
  type        = string
}