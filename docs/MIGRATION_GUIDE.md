# Migration Guide: Moving to a Layered Infrastructure

This guide provides steps to migrate from a monolithic Terraform structure to the layered approach.

## Prerequisites

1. Ensure you have Terraform v1.0.0 or higher
2. Set up an S3 bucket for remote state storage
3. Set up a DynamoDB table for state locking
4. Back up your current state files

## Step 1: Create the New Directory Structure

```bash
# Infrastructure layer
mkdir -p infrastructure/modules
mkdir -p infrastructure/environments/dev
mkdir -p infrastructure/environments/prod
mkdir -p infrastructure/environments/dr-pilot-light

# Cluster layer
mkdir -p cluster/modules
mkdir -p cluster/environments/dev
mkdir -p cluster/environments/prod
mkdir -p cluster/environments/dr-pilot-light

# Application layer
mkdir -p application/modules
mkdir -p application/environments/dev
mkdir -p application/environments/prod
mkdir -p application/environments/dr-pilot-light
```

## Step 2: Move Modules to Appropriate Layers

### Infrastructure Layer Modules
```bash
cp -r modules/network infrastructure/modules/
cp -r modules/iam infrastructure/modules/
cp -r modules/security infrastructure/modules/
```

### Cluster Layer Modules
```bash
# Create ECS cluster-specific module
mkdir -p cluster/modules/ecs_cluster

# Copy relevant parts of the ECS module
# (You'll need to modify the module to split cluster vs service components)

cp -r modules/monitoring cluster/modules/
```

### Application Layer Modules
```bash
cp -r modules/cicd application/modules/
cp -r modules/database application/modules/

# Create ECS service-specific module
mkdir -p application/modules/ecs_service

# Copy relevant parts of the ECS module
# (You'll need to modify the module to split cluster vs service components)
```

## Step 3: Set Up Backend Configuration

Create a backend configuration file (`backend.tf`) in each environment directory:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "infrastructure/dev/terraform.tfstate" # Adjust for each layer
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

## Step 4: Create Remote State Files

For each layer after the infrastructure layer, create remote state configuration as shown in the example files.

## Step 5: Migrate State

Use Terraform state manipulation commands to carefully move resources from your current state to the appropriate layer's state.

For example:

```bash
# For infrastructure layer (example for network module)
terraform state mv 'module.network' 'module.network'

# After moving resources, use terraform state pull/push to move state to new backend
```

## Step 6: Update CI/CD Pipelines

Update or create new GitHub Actions workflows for each layer according to the provided examples.

## Step 7: Test Deployment

Deploy the infrastructure layer first, then the cluster layer, and finally the application layer.

For initial testing, use `terraform plan` extensively to ensure no unexpected changes.

## Notes on State Migration

State migration is complex and should be tested thoroughly in a staging environment first. Consider the following approaches:

1. **Minimal Downtime Approach**: Create parallel environments and migrate one component at a time
2. **Complete Downtime Approach**: Remove entire infrastructure and redeploy with new structure (not recommended for production)
3. **Transitional Approach**: Keep the original environment running while building the new layered environment in parallel

## Troubleshooting

- If you encounter state lock issues, use `terraform force-unlock`
- For state migration problems, consider using `terraform state rm` followed by `terraform import` for problematic resources
- Keep backups of your state before any migration activities