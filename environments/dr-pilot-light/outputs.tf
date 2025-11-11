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