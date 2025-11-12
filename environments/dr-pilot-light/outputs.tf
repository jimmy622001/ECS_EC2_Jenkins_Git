# Network outputs
output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnets" {
  value = module.network.public_subnets
}

output "private_subnets" {
  value = module.network.private_subnets
}

output "database_subnets" {
  value = module.network.database_subnets
}

# Database outputs
output "db_instance_id" {
  value = module.database.db_instance_id
}

output "db_instance_address" {
  value = module.database.db_instance_address
}

# ECS outputs
output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

output "alb_dns_name" {
  value = module.ecs.alb_dns_name
}

output "alb_zone_id" {
  value = module.ecs.alb_zone_id
}

# Route53 failover outputs
output "health_check_id" {
  value = module.route53_failover.health_check_id
}

output "dr_failover_sns_topic_arn" {
  value = module.route53_failover.dr_failover_sns_topic_arn
}

output "route53_dns_name" {
  value = module.route53_failover.primary_dns_name
  description = "The DNS name for accessing the application (will route to primary or DR based on health)"
}

# DR Lambda outputs
output "dr_lambda_arn" {
  value = module.dr_lambda.lambda_arn
}

output "monthly_test_rule_arn" {
  value = module.dr_lambda.monthly_test_rule_arn
}