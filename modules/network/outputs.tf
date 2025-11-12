# Network Module - Outputs

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnets" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnets" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "database_subnets" {
  description = "IDs of the database subnets"
  value       = aws_subnet.database[*].id
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = var.availability_zones
}

output "alb_security_group" {
  description = "ID of ALB security group"
  value       = aws_security_group.alb.id
}

output "ecs_security_group" {
  description = "ID of ECS security group"
  value       = aws_security_group.ecs.id
}

output "db_security_group" {
  description = "ID of database security group"
  value       = aws_security_group.db.id
}

output "jenkins_security_group" {
  description = "ID of Jenkins security group"
  value       = aws_security_group.jenkins.id
}

# ElastiCache outputs
output "cache_subnets" {
  description = "List of ElastiCache subnet IDs"
  value       = aws_subnet.cache[*].id
}

output "cache_security_group" {
  description = "ID of ElastiCache security group"
  value       = aws_security_group.cache.id
}