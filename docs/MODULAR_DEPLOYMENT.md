# Modular Deployment Guide

## Overview

This project uses a modular deployment approach where infrastructure components can be deployed independently. This enables:

1. **Reduced Deployment Risk**: Changes to one component don't require redeploying the entire infrastructure
2. **Faster Iterations**: Application updates can be deployed without modifying core infrastructure
3. **Role-Based Access**: Different teams can manage different components

## Deployment Structure

Each environment has its own deployment configuration and can deploy any combination of the following modules:

1. **Network Module**: VPC, subnets, and network security
2. **IAM Module**: IAM roles and permissions
3. **ECS Module**: Container orchestration on EC2 instances
4. **Database Module**: RDS database
5. **CI/CD Module**: Jenkins and deployment pipeline
6. **Monitoring Module**: CloudWatch, Prometheus, and Grafana
7. **Security Module**: WAF and additional security controls

## Deployment Steps

### Prerequisites

- AWS CLI configured
- Terraform 1.0+ installed
- Access to target AWS account

### Step 1: Environment Preparation

1. Create environment-specific tfvars file:
   ```
   cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
   ```

2. Edit the `terraform.tfvars` file with appropriate values for your environment

3. Set up secrets:
   ```
   ./scripts/setup_secrets.sh dev
   ```

### Step 2: Modular Deployment

Use the deployment script to deploy specific components:

```bash
cd environments/dev
./deploy_infrastructure.sh network   # Deploy only the network module
./deploy_infrastructure.sh iam       # Deploy only the IAM module
./deploy_infrastructure.sh ecs       # Deploy only the ECS module
```

To deploy everything at once:

```bash
./deploy_infrastructure.sh all
```

You can also use the Makefile for common operations:

```bash
make init-dev    # Initialize Terraform for dev environment
make plan-dev    # Create a plan for dev environment
make apply-dev   # Apply the plan for dev environment
```

### Step 3: Verify Deployment

After deployment, verify resources in the AWS Console or using:

```bash
cd environments/dev
terraform output
```

## Dependency Management

The modules have dependencies on each other, which are handled through the deployment scripts:

1. **Network First**: The network module should be deployed first
2. **IAM Second**: IAM roles are needed by other resources
3. **Core Infrastructure**: ECS and database can be deployed next
4. **Add-on Services**: CI/CD and monitoring can be deployed last

## Environment-Specific Deployment

The project supports three environments:

1. **Development (dev)**: For development and testing
2. **Production (prod)**: For production workloads
3. **Disaster Recovery (dr-pilot-light)**: Pilot light DR setup

Each environment can be configured individually with its own parameters in the respective `terraform.tfvars` file.

## Using Existing Resources

If you already have some infrastructure components, you can set the corresponding `deploy_*` variables to `false` and provide the IDs of your existing resources. For example:

```hcl
# Use existing network resources
deploy_network = false
vpc_id = "vpc-12345678"
private_subnets = ["subnet-1234", "subnet-5678"]
public_subnets = ["subnet-abcd", "subnet-efgh"]
```

This flexibility allows you to integrate with existing infrastructure or migrate gradually.