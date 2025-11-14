#!/bin/bash
# AWS FIS Setup Script for Dev Environment
# This script sets up the necessary components for AWS FIS in the dev environment

set -e

# Configuration
PROJECT="project"
ENVIRONMENT="dev"
REGION="us-east-1"  # Change to your AWS region
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Setting up AWS FIS for the development environment..."

# 1. Create IAM Role for FIS
echo "Creating IAM role for FIS service..."
aws iam create-role \
    --role-name FisServiceRole-Dev \
    --assume-role-policy-document '{
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
    }'

# 2. Attach necessary policies
echo "Attaching policies to FIS role..."
aws iam attach-role-policy \
    --role-name FisServiceRole-Dev \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSFaultInjectionSimulatorEC2Access

aws iam attach-role-policy \
    --role-name FisServiceRole-Dev \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSFaultInjectionSimulatorECSAccess

# 3. Create custom policy for CloudWatch and RDS access
echo "Creating custom policy for additional permissions..."
aws iam create-policy \
    --policy-name FisCustomPolicy-Dev \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "cloudwatch:DescribeAlarms",
                    "rds:RebootDBInstance"
                ],
                "Resource": "*",
                "Condition": {
                    "StringEquals": {
                        "aws:ResourceTag/Environment": "dev"
                    }
                }
            }
        ]
    }'

# Attach the custom policy
aws iam attach-role-policy \
    --role-name FisServiceRole-Dev \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/FisCustomPolicy-Dev

# 4. Create CloudWatch Alarms for stop conditions
echo "Creating CloudWatch alarms for experiment stop conditions..."

# CPU High Alarm
aws cloudwatch put-metric-alarm \
    --alarm-name ${PROJECT}-${ENVIRONMENT}-cpu-high \
    --alarm-description "High CPU alarm for FIS experiments" \
    --metric-name CPUUtilization \
    --namespace AWS/ECS \
    --statistic Average \
    --period 60 \
    --threshold 90 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --dimensions Name=ClusterName,Value=${PROJECT}-${ENVIRONMENT}-cluster Name=ServiceName,Value=${PROJECT}-${ENVIRONMENT}-service

# Memory High Alarm
aws cloudwatch put-metric-alarm \
    --alarm-name ${PROJECT}-${ENVIRONMENT}-memory-high \
    --alarm-description "High Memory alarm for FIS experiments" \
    --metric-name MemoryUtilization \
    --namespace AWS/ECS \
    --statistic Average \
    --period 60 \
    --threshold 90 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --dimensions Name=ClusterName,Value=${PROJECT}-${ENVIRONMENT}-cluster Name=ServiceName,Value=${PROJECT}-${ENVIRONMENT}-service

# Task Count Low Alarm
aws cloudwatch put-metric-alarm \
    --alarm-name ${PROJECT}-${ENVIRONMENT}-task-count-low \
    --alarm-description "Task count low alarm for FIS experiments" \
    --metric-name RunningTaskCount \
    --namespace ECS/ContainerInsights \
    --statistic Average \
    --period 60 \
    --threshold 1 \
    --comparison-operator LessThanThreshold \
    --evaluation-periods 1 \
    --dimensions Name=ClusterName,Value=${PROJECT}-${ENVIRONMENT}-cluster Name=ServiceName,Value=${PROJECT}-${ENVIRONMENT}-service

# Latency High Alarm
aws cloudwatch put-metric-alarm \
    --alarm-name ${PROJECT}-${ENVIRONMENT}-latency-high \
    --alarm-description "High latency alarm for FIS experiments" \
    --metric-name TargetResponseTime \
    --namespace AWS/ApplicationELB \
    --statistic Average \
    --period 60 \
    --threshold 2 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --dimensions Name=LoadBalancer,Value=${PROJECT}-${ENVIRONMENT}-alb

# 5. Create experiment templates with proper variables
echo "Creating FIS experiment templates..."

# Get ARNs of created alarms
CPU_ALARM_ARN="arn:aws:cloudwatch:${REGION}:${ACCOUNT_ID}:alarm:${PROJECT}-${ENVIRONMENT}-cpu-high"
MEMORY_ALARM_ARN="arn:aws:cloudwatch:${REGION}:${ACCOUNT_ID}:alarm:${PROJECT}-${ENVIRONMENT}-memory-high"
TASK_COUNT_ALARM_ARN="arn:aws:cloudwatch:${REGION}:${ACCOUNT_ID}:alarm:${PROJECT}-${ENVIRONMENT}-task-count-low"
LATENCY_ALARM_ARN="arn:aws:cloudwatch:${REGION}:${ACCOUNT_ID}:alarm:${PROJECT}-${ENVIRONMENT}-latency-high"
FIS_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/FisServiceRole-Dev"

# Get cluster and service info
ECS_CLUSTER_NAME="${PROJECT}-${ENVIRONMENT}-cluster"
ECS_SERVICE_NAME="${PROJECT}-${ENVIRONMENT}-service"

# Replace variables in template files
TEMPLATES_DIR="./scripts/fis_templates"

# CPU Stress template
sed -i "s|\${CPU_ALARM_ARN}|${CPU_ALARM_ARN}|g" ${TEMPLATES_DIR}/dev_cpu_stress.json
sed -i "s|\${FIS_ROLE_ARN}|${FIS_ROLE_ARN}|g" ${TEMPLATES_DIR}/dev_cpu_stress.json

# Network latency template
sed -i "s|\${LATENCY_ALARM_ARN}|${LATENCY_ALARM_ARN}|g" ${TEMPLATES_DIR}/dev_network_latency.json
sed -i "s|\${FIS_ROLE_ARN}|${FIS_ROLE_ARN}|g" ${TEMPLATES_DIR}/dev_network_latency.json

# Task termination template
sed -i "s|\${TASK_COUNT_ALARM_ARN}|${TASK_COUNT_ALARM_ARN}|g" ${TEMPLATES_DIR}/dev_task_termination.json
sed -i "s|\${FIS_ROLE_ARN}|${FIS_ROLE_ARN}|g" ${TEMPLATES_DIR}/dev_task_termination.json
sed -i "s|\${ECS_CLUSTER_NAME}|${ECS_CLUSTER_NAME}|g" ${TEMPLATES_DIR}/dev_task_termination.json
sed -i "s|\${ECS_SERVICE_NAME}|${ECS_SERVICE_NAME}|g" ${TEMPLATES_DIR}/dev_task_termination.json

# Get task ARN - will need to be updated at runtime
ECS_TASK_ARN=$(aws ecs list-tasks --cluster ${ECS_CLUSTER_NAME} --service-name ${ECS_SERVICE_NAME} --query 'taskArns[0]' --output text)
sed -i "s|\${ECS_TASK_ARN}|${ECS_TASK_ARN}|g" ${TEMPLATES_DIR}/dev_task_termination.json

# 6. Create experiment templates in AWS FIS
echo "Creating FIS CPU stress experiment template..."
aws fis create-experiment-template \
    --cli-input-json file://${TEMPLATES_DIR}/dev_cpu_stress.json

echo "Creating FIS network latency experiment template..."
aws fis create-experiment-template \
    --cli-input-json file://${TEMPLATES_DIR}/dev_network_latency.json

echo "Creating FIS task termination experiment template..."
aws fis create-experiment-template \
    --cli-input-json file://${TEMPLATES_DIR}/dev_task_termination.json

# 7. Create CloudWatch Dashboard for monitoring experiments
echo "Creating CloudWatch dashboard for FIS experiments..."

cat > scripts/cloudwatch/dev_fis_dashboard.json << EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/ECS", "CPUUtilization", "ClusterName", "${PROJECT}-${ENVIRONMENT}-cluster", "ServiceName", "${PROJECT}-${ENVIRONMENT}-service", { "stat": "Average" } ]
        ],
        "period": 60,
        "region": "${REGION}",
        "title": "ECS CPU Utilization During FIS Experiment",
        "view": "timeSeries",
        "stacked": false
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/ECS", "MemoryUtilization", "ClusterName", "${PROJECT}-${ENVIRONMENT}-cluster", "ServiceName", "${PROJECT}-${ENVIRONMENT}-service", { "stat": "Average" } ]
        ],
        "period": 60,
        "region": "${REGION}",
        "title": "ECS Memory Utilization During FIS Experiment",
        "view": "timeSeries",
        "stacked": false
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "ECS/ContainerInsights", "RunningTaskCount", "ClusterName", "${PROJECT}-${ENVIRONMENT}-cluster", "ServiceName", "${PROJECT}-${ENVIRONMENT}-service", { "stat": "Average" } ]
        ],
        "period": 60,
        "region": "${REGION}",
        "title": "ECS Running Task Count During FIS Experiment",
        "view": "timeSeries",
        "stacked": false
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "${PROJECT}-${ENVIRONMENT}-alb", { "stat": "Average" } ]
        ],
        "period": 60,
        "region": "${REGION}",
        "title": "ALB Response Time During FIS Experiment",
        "view": "timeSeries",
        "stacked": false
      }
    }
  ]
}
EOF

aws cloudwatch put-dashboard \
    --dashboard-name DevFISExperiments \
    --dashboard-body file://scripts/cloudwatch/dev_fis_dashboard.json

echo "Setup complete! Your AWS FIS experiment templates and monitoring are ready to use in the dev environment."
echo ""
echo "Next steps:"
echo "1. Review created experiment templates: aws fis list-experiment-templates"
echo "2. Run your first experiment: aws fis start-experiment --experiment-template-id <TEMPLATE_ID>"
echo "3. Monitor the experiment in CloudWatch dashboard: DevFISExperiments"