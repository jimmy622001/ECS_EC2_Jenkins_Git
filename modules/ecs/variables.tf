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

variable "alb_security_group" {
  description = "ID of the ALB security group"
  type        = string
}

variable "ecs_security_group" {
  description = "ID of the ECS security group"
  type        = string
}

# IAM variables
variable "ecs_task_execution_role" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "ecs_task_role" {
  description = "ARN of the ECS task role"
  type        = string
}

# ECS Cluster variables
variable "container_insights" {
  description = "Enable container insights for ECS cluster"
  type        = bool
}

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

# ECS Task variables
variable "task_cpu" {
  description = "CPU units for the task"
  type        = number
}

variable "task_memory" {
  description = "Memory for the task in MiB"
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

variable "desired_task_count" {
  description = "Desired number of tasks for ECS service"
  type        = number
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