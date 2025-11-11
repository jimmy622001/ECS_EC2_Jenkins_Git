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

variable "public_subnets" {
  description = "IDs of the public subnets"
  type        = list(string)
}

variable "jenkins_security_group" {
  description = "ID of the Jenkins security group"
  type        = string
}

# IAM variables
variable "jenkins_instance_profile" {
  description = "Name of the Jenkins instance profile"
  type        = string
}

variable "codedeploy_role" {
  description = "ARN of the CodeDeploy service role"
  type        = string
}

# Jenkins variables
variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins"
  type        = string
}

variable "ssh_key_name" {
  description = "SSH key name for Jenkins EC2 instance"
  type        = string
}

# CodeDeploy variables
variable "github_repository" {
  description = "GitHub repository for application"
  type        = string
}

variable "codedeploy_group_name" {
  description = "Name of the CodeDeploy deployment group"
  type        = string
}

# ECS variables (for CodeDeploy)
variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the ECS service"
  type        = string
}

# ALB variables (for CodeDeploy)
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