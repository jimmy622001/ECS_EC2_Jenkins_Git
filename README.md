# ECS with Jenkins CI/CD and Monitoring Infrastructure

## Overview

This Terraform project deploys a complete AWS infrastructure including:
- VPC with public/private subnets and dedicated database subnet
- ECS Cluster using EC2 instances with blue/green deployment capability
- CI/CD pipeline with Jenkins and GitHub integration on self-healing EC2 instances
- RDS database in a private subnet
- Prometheus and Grafana monitoring solution
- Automated patching and AMI management

## Project Architecture

The infrastructure is designed with a modular approach allowing for independent deployment of components. This enables:
- Infrastructure changes without impacting applications
- Separate CI/CD processes for infrastructure and applications
- Environment-specific configurations (prod, dev, DR)
- Well-organized outputs in dedicated output files for each module
- Separate infrastructure environments with proper CIDR block segmentation
- Enhanced security with environment isolation

## Module Structure

The infrastructure is organized into the following modules:

### 1. Network Module
- **Purpose**: Establishes the network foundation
- **Components**:
    - VPC with public and private subnets
    - Internet Gateway and NAT Gateway
    - Route tables and security groups
    - VPC Flow logs and S3 bucket for access logs

### 2. IAM Module
- **Purpose**: Handles security and permissions
- **Components**:
    - ECS task execution and task roles
    - Jenkins IAM role for ECS deployments
    - Monitoring service roles

### 3. ECS Module
- **Purpose**: Runs containerized applications
- **Components**:
    - Cluster configuration (EC2 instances)
    - Task definitions and services with blue/green deployment capability
    - Load balancer and auto scaling
    - CodeDeploy integration for zero-downtime deployments

### 4. Database Module
- **Purpose**: Provides persistent storage
- **Components**:
    - RDS instance in private subnet
    - Encrypted storage with backups
    - High availability configuration

### 5. CI/CD Module
- **Purpose**: Enables continuous integration/deployment
- **Components**:
    - Jenkins server in Auto Scaling Group with latest ECS-optimized AMIs
    - GitHub integration setup
    - Deployment pipeline to ECS
    - Self-healing infrastructure with health checks

### 6. Monitoring Module
- **Purpose**: Observability and metrics
- **Components**:
    - Prometheus for metrics collection
    - Grafana for visualization
    - Alerting configuration

### 7. Security Module
- **Purpose**: Implements OWASP and AWS security best practices
- **Components**:
    - WAF configuration with OWASP rules
    - Security headers and TLS configuration
    - GuardDuty and AWS Config integration

## Layered Infrastructure Approach

This project implements a layered approach to infrastructure management:

1. **Infrastructure Layer** (infrequent changes)
   - Core network resources, IAM, and security components

2. **Cluster Layer** (occasional changes)
   - ECS cluster, load balancers, and monitoring infrastructure

3. **Application Layer** (frequent changes)
   - Container definitions, services, and application-specific configurations

This layered approach provides:
- Reduced risk when deploying changes
- Faster application deployments
- Better access control between teams
- Improved CI/CD workflow

## Environment Configuration

The project supports multiple environments with specialized configurations:

### Development Environment
- Optimized for cost efficiency with spot instances
- Scaled-down resources for development and testing
- Full feature parity with production for accurate testing
- Dedicated VPC with its own DNS configuration

### Production Environment
- Highly available configuration using on-demand instances
- Enhanced scaling parameters for production workloads
- Stricter security controls and monitoring
- Isolated VPC with enterprise-grade security controls

### DR Pilot Light Environment
- Minimal running infrastructure in a secondary AWS region
- Uses spot instances for cost efficiency during normal operations
- Auto scaling capabilities to rapidly expand during failover events

## Secrets Management

This project uses AWS Secrets Manager for handling sensitive information:

1. No sensitive data is stored in the Terraform code
2. All secrets are referenced from AWS Secrets Manager
3. Environment-specific secrets are separated by path

## GitHub Workflow

The project uses GitHub for source control with the following branch strategy:
- `main`: Production-ready code
- `dev`: Development environment code
- `feature/*`: Feature branches
- `hotfix/*`: Emergency fixes

CI/CD pipelines are configured for automatic testing and deployment.

## Additional Documentation

For more detailed documentation, see:
- [Modular Deployment Guide](docs/MODULAR_DEPLOYMENT.md)
- [Layered Infrastructure Guide](docs/LAYERED_INFRASTRUCTURE.md)
- [Migration Guide](docs/MIGRATION_GUIDE.md)
- [Usage Instructions](USAGE.md)