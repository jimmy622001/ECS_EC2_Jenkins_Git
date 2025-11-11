# Network Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = var.deploy_network ? module.network.vpc_id : var.vpc_id
}

output "public_subnets" {
  description = "IDs of the public subnets"
  value       = var.deploy_network ? module.network.public_subnets : var.public_subnets
}

output "private_subnets" {
  description = "IDs of the private subnets"
  value       = var.deploy_network ? module.network.private_subnets : var.private_subnets
}

output "database_subnets" {
  description = "IDs of the database subnets"
  value       = var.deploy_network ? module.network.database_subnets : var.database_subnets
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = var.deploy_ecs ? module.ecs.ecs_cluster_name : var.ecs_cluster_name
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = var.deploy_ecs ? module.ecs.alb_dns_name : "not-created"
}

# Database Outputs
output "db_instance_address" {
  description = "Address of the RDS instance"
  value       = var.deploy_database ? module.database.db_instance_address : "not-created"
}

output "db_instance_port" {
  description = "Port of the RDS instance"
  value       = var.deploy_database ? module.database.db_instance_port : "not-created"
}

# CI/CD Outputs
output "jenkins_public_ip" {
  description = "Public IP of the Jenkins EC2 instance"
  value       = var.deploy_cicd ? module.cicd.jenkins_public_ip : "not-created"
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = var.deploy_cicd ? module.cicd.ecr_repository_url : "not-created"
}

# Monitoring Outputs
output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = var.deploy_monitoring ? module.monitoring.dashboard_name : "not-created"
}

# Security Outputs
output "waf_web_acl_id" {
  description = "ID of the WAF WebACL"
  value       = var.deploy_security ? module.security.waf_web_acl_id : "not-created"
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = var.deploy_security && var.enable_guardduty ? module.security.guardduty_detector_id : "not-created"
}