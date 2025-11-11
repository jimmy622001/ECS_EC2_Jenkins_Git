# Layered Infrastructure Approach

This document outlines the layered approach for our Terraform infrastructure, separating components by their change frequency.

## Overview

The infrastructure is divided into three layers:

1. **Infrastructure Layer** (infrequent changes)
   - VPC, subnets, route tables, internet gateways
   - IAM roles and policies
   - Security groups
   - Core security services (Security Hub, GuardDuty)

2. **Cluster Layer** (occasional changes)
   - ECS cluster configuration
   - Load balancers
   - Auto scaling groups
   - EC2 launch templates
   - Monitoring infrastructure

3. **Application Layer** (frequent changes)
   - ECS task definitions and services
   - Container configurations
   - CI/CD pipelines
   - Database configurations

## Directory Structure

```
ECS_EC2_Jenkins_Git/
├── infrastructure/              # Base infrastructure (infrequent changes)
│   ├── modules/
│   │   ├── network/
│   │   ├── iam/
│   │   └── security/            # Core security components
│   ├── environments/
│   │   ├── dev/
│   │   ├── prod/
│   │   └── dr-pilot-light/
│   └── outputs/                 # Terraform state outputs for cluster layer
│
├── cluster/                     # ECS cluster layer (occasional changes)
│   ├── modules/
│   │   ├── ecs_cluster/
│   │   └── monitoring/
│   ├── environments/
│   │   ├── dev/
│   │   ├── prod/
│   │   └── dr-pilot-light/
│   └── outputs/                 # Terraform state outputs for application layer
│
└── application/                 # Application layer (frequent changes)
    ├── modules/
    │   ├── cicd/
    │   ├── ecs_service/
    │   └── database/
    ├── environments/
    │   ├── dev/
    │   ├── prod/
    │   └── dr-pilot-light/
    └── pipelines/               # CI/CD configurations
```

## Implementing the Layered Approach

### 1. Data Sharing Between Layers

To share data between layers, we use Terraform remote state:

```hcl
# In cluster/environments/dev/main.tf
data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "your-terraform-state-bucket"
    key    = "infrastructure/dev/terraform.tfstate"
    region = "us-east-1"
  }
}

# Access infrastructure outputs
locals {
  vpc_id = data.terraform_remote_state.infrastructure.outputs.vpc_id
}
```

### 2. Pipeline Configuration

Create separate GitHub Actions workflows for each layer:

```yaml
# .github/workflows/infrastructure-apply.yml
name: "Infrastructure Apply"
on:
  push:
    branches:
      - main
    paths:
      - 'infrastructure/**'
      
# .github/workflows/cluster-apply.yml
name: "Cluster Apply"
on:
  push:
    branches:
      - main
    paths:
      - 'cluster/**'
      
# .github/workflows/application-apply.yml
name: "Application Apply"
on:
  push:
    branches:
      - main
    paths:
      - 'application/**'
```

### 3. State Management

Each layer should have its own state file to minimize concurrent operations:

```
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "infrastructure/dev/terraform.tfstate"  # Different key per layer
    region = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}
```

## Benefits of This Approach

1. **Reduced Risk**: Changes to the application layer won't affect the base infrastructure
2. **Faster Deployments**: Application deployments don't need to check the entire infrastructure
3. **Better Access Control**: Teams can have different permissions for different layers
4. **Improved CI/CD Flow**: Shorter feedback loops for application changes

## Implementation Steps

1. Reorganize the modules into their respective layers
2. Set up remote state configuration for each layer
3. Create layer-specific CI/CD pipelines
4. Migrate existing state carefully using state manipulation commands