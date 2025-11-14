#!/bin/bash
# AWS Fault Injection Simulator (FIS) Setup Script
# This script helps set up AWS FIS experiments for ECS/EC2/Jenkins infrastructure

set -e

# Check for AWS CLI installation
if ! command -v aws &>/dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &>/dev/null; then
    echo "jq is not installed. Please install it first."
    exit 1
fi

# Variables - modify these as needed
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
REGION=$(aws configure get region)
ENVIRONMENT="dev"  # Change to target environment
IAM_ROLE_NAME="FISExecutionRole"
EXPERIMENT_TEMPLATE_NAME="ECS-Task-Failure-Test"

echo "Setting up AWS FIS for account: $ACCOUNT_ID in region: $REGION"
echo "Target environment: $ENVIRONMENT"

# Create IAM Role for FIS if it doesn't exist
echo "Checking for FIS IAM Role..."
if ! aws iam get-role --role-name "$IAM_ROLE_NAME" &>/dev/null; then
    echo "Creating FIS IAM Role: $IAM_ROLE_NAME"
    
    # Create trust policy document
    cat > fis-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "fis.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
    
    # Create IAM role
    aws iam create-role \
        --role-name "$IAM_ROLE_NAME" \
        --assume-role-policy-document file://fis-trust-policy.json
    
    # Create permission policy document
    cat > fis-permissions-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:StopInstances",
        "ec2:RebootInstances",
        "ecs:ListClusters",
        "ecs:ListTasks", 
        "ecs:DescribeClusters",
        "ecs:DescribeTasks",
        "ecs:StopTask",
        "rds:DescribeDBInstances",
        "rds:FailoverDBCluster",
        "rds:RebootDBInstance",
        "elasticache:DescribeReplicationGroups",
        "elasticache:DescribeCacheClusters",
        "elasticache:RebootCacheCluster",
        "cloudwatch:DescribeAlarms"
      ],
      "Resource": "*"
    }
  ]
}
EOF
    
    # Attach policy to role
    aws iam put-role-policy \
        --role-name "$IAM_ROLE_NAME" \
        --policy-name "FISPermissions" \
        --policy-document file://fis-permissions-policy.json
    
    echo "IAM Role created successfully"
else
    echo "IAM Role $IAM_ROLE_NAME already exists"
fi

# Create CloudWatch Alarm for experiment stop condition
echo "Creating CloudWatch Alarm for FIS experiment stop condition..."
ALARM_NAME="FIS-ExperimentStopCondition-$ENVIRONMENT"

aws cloudwatch put-metric-alarm \
    --alarm-name "$ALARM_NAME" \
    --alarm-description "Stop FIS experiment if error rate exceeds threshold" \
    --metric-name "HTTPCode_Target_5XX_Count" \
    --namespace "AWS/ApplicationELB" \
    --statistic "Sum" \
    --period 60 \
    --evaluation-periods 2 \
    --threshold 5 \
    --comparison-operator "GreaterThanThreshold" \
    --treat-missing-data "notBreaching" \
    --dimensions "Name=LoadBalancer,Value=app/your-alb/REPLACE_WITH_YOUR_ALB_ID"

echo "CloudWatch Alarm created: $ALARM_NAME"

# Get ECS cluster information
echo "Getting ECS cluster information..."
ECS_CLUSTER=$(aws ecs list-clusters --query "clusterArns[0]" --output text)
ECS_CLUSTER_NAME=$(echo $ECS_CLUSTER | awk -F'/' '{print $2}')

echo "Found ECS cluster: $ECS_CLUSTER_NAME"

# Create FIS experiment template
echo "Creating FIS experiment template: $EXPERIMENT_TEMPLATE_NAME"

cat > fis-experiment-template.json << EOF
{
  "description": "Terminate random ECS tasks",
  "targets": {
    "ecs-tasks": {
      "resourceType": "aws:ecs:task",
      "resourceArns": ["$ECS_CLUSTER"],
      "selectionMode": "COUNT(2)"
    }
  },
  "actions": {
    "terminate-tasks": {
      "actionId": "aws:ecs:stop-task",
      "parameters": {
        "reason": "FIS experiment"
      },
      "targets": {
        "Tasks": "ecs-tasks"
      }
    }
  },
  "stopConditions": [
    {
      "source": "aws:cloudwatch:alarm",
      "value": "arn:aws:cloudwatch:$REGION:$ACCOUNT_ID:alarm:$ALARM_NAME"
    }
  ],
  "roleArn": "arn:aws:iam::$ACCOUNT_ID:role/$IAM_ROLE_NAME",
  "tags": {
    "Name": "$EXPERIMENT_TEMPLATE_NAME",
    "Environment": "$ENVIRONMENT"
  }
}
EOF

TEMPLATE_ID=$(aws fis create-experiment-template \
    --cli-input-json file://fis-experiment-template.json \
    --query 'experimentTemplate.id' --output text)

echo "FIS experiment template created with ID: $TEMPLATE_ID"

# Clean up temporary files
rm -f fis-trust-policy.json fis-permissions-policy.json fis-experiment-template.json

echo "============================================="
echo "AWS FIS Setup Complete!"
echo "To run the experiment, use the following command:"
echo "aws fis start-experiment --experiment-template-id $TEMPLATE_ID --tags Purpose=Resilience-Testing"
echo "============================================="

# Usage instructions
cat << EOF

INSTRUCTIONS:

1. Review the experiment template in AWS Console before running
2. Verify the CloudWatch alarm is properly configured with your ALB
3. Update the experiment template as needed for your environment
4. Schedule the experiment during a maintenance window
5. Monitor the experiment in AWS FIS Console

For more information, see the AWS FIS Playbook in docs/AWS_FIS_PLAYBOOK.md
EOF