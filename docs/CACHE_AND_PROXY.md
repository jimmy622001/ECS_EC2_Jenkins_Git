# ElastiCache and RDS Proxy Integration Guide

This document explains how to enable and use the ElastiCache and RDS Proxy components that are included (but commented out) in the project.

## When to Enable These Components

### RDS Proxy

Enable RDS Proxy when:

1. Your application has a large number of database connections
2. You need connection pooling to improve database efficiency
3. You're experiencing connection issues during database failovers
4. You need additional security for database access
5. Your environment has scaled to production levels with significant traffic

### ElastiCache

Enable ElastiCache when:

1. Your application performs frequent, repetitive database queries
2. You need a way to store and share session data
3. Your database is experiencing high load that could be mitigated by caching
4. You need to improve response times for specific operations
5. Your application serves data that doesn't change frequently

## How to Enable RDS Proxy

1. Edit the `modules/database/main.tf` file and uncomment the RDS Proxy configuration section:

```hcl
# Uncomment this section
resource "aws_iam_role" "proxy_role" {
  name = "${var.project}-${var.environment}-proxy-role"
  # ...
}

resource "aws_iam_role_policy" "proxy_policy" {
  name = "${var.project}-${var.environment}-proxy-policy"
  # ...
}

resource "aws_db_proxy" "main" {
  name                   = "${var.project}-${var.environment}-db-proxy"
  # ...
}

resource "aws_db_proxy_default_target_group" "main" {
  # ...
}

resource "aws_db_proxy_target" "main" {
  # ...
}
```

2. Edit the `modules/database/outputs.tf` file and uncomment the RDS Proxy outputs:

```hcl
output "db_proxy_endpoint" {
  description = "Endpoint of the RDS Proxy"
  value       = aws_db_proxy.main.endpoint
}

output "db_proxy_arn" {
  description = "ARN of the RDS Proxy"
  value       = aws_db_proxy.main.arn
}

output "db_proxy_target_endpoint" {
  description = "Connection endpoint for the database proxy"
  value       = "${var.db_engine}://${var.db_username}:${sensitive(var.db_password == "" ? random_password.db_password[0].result : var.db_password)}@${aws_db_proxy.main.endpoint}:${aws_db_instance.main.port}/${var.db_name}"
  sensitive   = true
}
```

3. Apply the changes with Terraform:

```bash
terraform plan -target=module.database
terraform apply -target=module.database
```

4. Update your application to use the RDS Proxy endpoint instead of connecting directly to the RDS instance. Update the database URL in your application configuration to use the proxy endpoint.

## How to Enable ElastiCache

1. Edit the `modules/network/main.tf` file and uncomment the ElastiCache security group:

```hcl
resource "aws_security_group" "cache" {
  name        = "${var.project}-${var.environment}-cache-sg"
  # ...
}
```

2. Edit the `modules/network/outputs.tf` file and uncomment the cache_security_group output:

```hcl
output "cache_security_group" {
  description = "ID of ElastiCache security group"
  value       = aws_security_group.cache.id
}
```

3. Uncomment the ElastiCache module in `environments/dev/main.tf`:

```hcl
module "cache" {
  source = "../../modules/cache"

  project     = var.project
  environment = var.environment

  private_subnets     = module.network.private_subnets
  cache_security_group = module.network.cache_security_group
  
  cache_node_type     = var.cache_node_type
  cache_nodes         = var.cache_nodes
}
```

4. Uncomment the cache-related variables in `environments/dev/variables.tf`:

```hcl
variable "cache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro" 
}

variable "cache_nodes" {
  description = "Number of Redis cache nodes"
  type        = number
  default     = 1
}

variable "cache_security_group" {
  description = "Existing ElastiCache security group ID (when deploy_network = false)"
  type        = string
  default     = ""
}
```

5. Uncomment the ElastiCache resources in `modules/cache/main.tf`: 

```hcl
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-cache-subnet-group"
  subnet_ids = var.private_subnets
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project}-${var.environment}-redis"
  # ...
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "redis_port" {
  description = "Redis cluster port"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].port
}
```

6. Apply the changes with Terraform:

```bash
terraform plan
terraform apply
```

7. Update your application to use ElastiCache for caching or session management. You'll need to add Redis client library to your application and configure it to use the ElastiCache endpoint.

## Application Integration

### Integrating RDS Proxy

Update your database connection string in your Node.js application like this:

```javascript
const { Pool } = require('pg'); // For PostgreSQL
// or
const mysql = require('mysql2/promise'); // For MySQL

// Get secrets from AWS Secrets Manager
const getSecrets = async () => {
  // Implementation to retrieve secrets...
};

(async function() {
  const secrets = await getSecrets();
  
  // For PostgreSQL
  const pool = new Pool({
    host: secrets.proxyEndpoint, // Use proxy endpoint instead of direct RDS endpoint
    port: secrets.port,
    database: secrets.dbname,
    user: secrets.username,
    password: secrets.password
  });
  
  // For MySQL
  const pool = await mysql.createPool({
    host: secrets.proxyEndpoint, // Use proxy endpoint instead of direct RDS endpoint
    port: secrets.port,
    database: secrets.dbname,
    user: secrets.username,
    password: secrets.password
  });
})();
```

### Integrating ElastiCache

Add Redis caching to your application:

```javascript
const redis = require('redis');
const { promisify } = require('util');

// Get cache endpoint from environment variables or parameter store
const REDIS_ENDPOINT = process.env.REDIS_ENDPOINT;
const REDIS_PORT = process.env.REDIS_PORT || 6379;

// Create Redis client
const redisClient = redis.createClient({
  host: REDIS_ENDPOINT,
  port: REDIS_PORT
});

// Convert callback-based methods to promises
const getAsync = promisify(redisClient.get).bind(redisClient);
const setAsync = promisify(redisClient.set).bind(redisClient);
const delAsync = promisify(redisClient.del).bind(redisClient);

// Example usage in an Express route
app.get('/api/products/:id', async (req, res) => {
  const productId = req.params.id;
  const cacheKey = `product:${productId}`;
  
  try {
    // Try to get from cache first
    const cachedProduct = await getAsync(cacheKey);
    
    if (cachedProduct) {
      return res.json(JSON.parse(cachedProduct));
    }
    
    // If not in cache, get from database
    const product = await getProductFromDatabase(productId);
    
    // Store in cache for 1 hour
    await setAsync(cacheKey, JSON.stringify(product), 'EX', 3600);
    
    return res.json(product);
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});
```

## Cost Considerations

Remember that enabling these services will increase your AWS costs:

- RDS Proxy: ~$0.015 per VPC-hour (~$10-11/month), plus data processing charges
- ElastiCache (cache.t3.micro): ~$13/month
- ElastiCache (cache.m5.large for production): ~$100/month

It's recommended to enable these services only when your application has reached a scale that justifies the additional cost and complexity.