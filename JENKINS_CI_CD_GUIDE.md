# Jenkins CI/CD Pipeline Guide

This guide explains the Jenkins CI/CD pipeline implementation in this project and provides information on separate environments.

## Pipeline Architecture

The repository includes a `Jenkinsfile` that defines a complete CI/CD pipeline for both development and production environments.
The pipeline is designed to work with the existing infrastructure:

- Jenkins EC2 instance managed by Terraform
- AWS ECR repository for Docker images
- AWS CodeDeploy for blue/green deployments to ECS

## Environment-Specific Infrastructure

### Separate VPCs for Dev and Prod

**Yes, separate VPCs for development and production environments are strongly recommended** for the following reasons:

1. **Security Isolation**: Complete network isolation prevents potential security breaches in development from affecting production.

2. **Resource Isolation**: Separate resource pools ensure that development workloads never impact production performance.

3. **DNS Separation**: Each environment can have its own Route 53 hosted zones and DNS records without conflict.

4. **IAM Segregation**: Simplified IAM policies with clearer boundaries between environments.

5. **Compliance Requirements**: Many compliance frameworks require separation between environments.

6. **Testing Network Configurations**: Network changes can be tested in development without risking production.

7. **Cost Allocation**: Easier cost tracking and allocation between environments.

### Current Architecture

The current Terraform configuration supports this separation through:

- Environment-specific variables for each VPC
- Separate state files for each environment
- Environment-specific DNS configurations
- Distinct security groups and network ACLs
- Separate CI/CD pipelines (controlled by the Jenkinsfile)

## CI/CD Pipeline Components

The Jenkins pipeline consists of these main stages:

1. **Checkout**: Clone the repository and get the latest code
2. **Build**: Build the application for the target environment
3. **Test**: Run unit and integration tests
4. **Security Scan**: Perform security scans and code quality analyses
5. **Build and Push Docker Image**: Create a Docker image and push to ECR
6. **Terraform Plan**: Plan infrastructure changes using Terraform
7. **Approve Deployment**: Manual approval step (for production only)
8. **Deploy to ECS**: Apply infrastructure changes and trigger deployment

## Setting Up the Pipeline

1. **Configure Jenkins**:
   - Install required plugins: AWS, Docker, Pipeline, etc.
   - Set up AWS credentials in Jenkins
   - Configure SonarQube integration

2. **Create Pipeline Job**:
   - Create a new Pipeline job in Jenkins
   - Point to the repository containing the Jenkinsfile
   - Configure webhook from GitHub for automatic triggers

3. **Environment-Specific Parameters**:
   - The pipeline uses parameters to determine the target environment
   - Additional parameters control test execution and deployment

## Infrastructure Requirements

For this multi-environment approach with separate VPCs to work effectively:

1. **Network Configuration**:
   - Separate CIDR blocks for each environment
   - Transit Gateway for inter-VPC communication (if required)
   - Environment-specific subnets with consistent naming

2. **DNS Setup**:
   - Route 53 hosted zones for each environment
   - Clear DNS naming convention (e.g., app.dev.example.com and app.example.com)

3. **Load Balancers**:
   - Each environment has its own ALB/NLB
   - Separate target groups for blue/green deployments

4. **ECS Clusters**:
   - Dedicated ECS cluster per environment
   - Environment-specific capacity providers

## Benefits of This Approach

1. **Clear Separation of Concerns**:
   - Development changes don't impact production
   - Easier to manage permissions and access controls

2. **Improved Testing**:
   - Complete environment testing before production deployment
   - Realistic load testing without impacting production

3. **Better Security Stance**:
   - Production-only security controls
   - Reduced attack surface for production environment

4. **Operational Efficiency**:
   - Automated deployments to both environments
   - Consistent infrastructure across environments