#!/bin/bash

# Script for setting up AWS Secrets Manager

# Exit on any error
set -e

# Check for AWS CLI
if ! command -v aws &> /dev/null; then
    echo "AWS CLI not found. Please install it first."
    exit 1
fi

# Environment
ENV=${1:-dev}
valid_envs=("dev" "prod" "dr-pilot-light")

# Validate environment
if [[ ! " ${valid_envs[@]} " =~ " ${ENV} " ]]; then
    echo "Invalid environment: $ENV"
    echo "Valid environments: dev, prod, dr-pilot-light"
    exit 1
fi

# Project name
PROJECT="ecs-jenkins-github"

# Secret path in AWS Secrets Manager
SECRET_PATH="/${PROJECT}/${ENV}/database"

# Read the secrets JSON file
SECRETS_FILE="environments/${ENV}/secrets_template.json"
if [ ! -f "$SECRETS_FILE" ]; then
    echo "Secrets file not found: $SECRETS_FILE"
    exit 1
fi

# Create or update the secret
echo "Creating/updating AWS Secrets Manager secret at path: $SECRET_PATH"
aws secretsmanager create-secret \
    --name "$SECRET_PATH" \
    --description "Database credentials for ${PROJECT} ${ENV} environment" \
    --secret-string file://$SECRETS_FILE \
    --region $(aws configure get region) \
    2>/dev/null || \
aws secretsmanager update-secret \
    --secret-id "$SECRET_PATH" \
    --secret-string file://$SECRETS_FILE \
    --region $(aws configure get region)

echo "Secret created/updated successfully at path: $SECRET_PATH"