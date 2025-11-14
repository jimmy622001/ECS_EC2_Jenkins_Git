# AWS Fault Injection Simulator (FIS) Implementation Guide

This guide provides an overview of the AWS Fault Injection Simulator implementation for the ECS/EC2/Jenkins infrastructure. It serves as a quick reference for running chaos engineering experiments using AWS FIS.

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Available Experiment Templates](#available-experiment-templates)
4. [Running Experiments](#running-experiments)
5. [Monitoring and Dashboards](#monitoring-and-dashboards)
6. [Reporting](#reporting)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

## Introduction

AWS Fault Injection Simulator (FIS) is a managed service for running fault injection experiments on AWS workloads. This implementation integrates FIS with our ECS/EC2/Jenkins infrastructure to perform controlled chaos engineering experiments.

For comprehensive details, refer to the full [AWS FIS Playbook](./AWS_FIS_PLAYBOOK.md).

## Getting Started

### Prerequisites

1. AWS CLI installed and configured
2. jq utility installed
3. Appropriate IAM permissions

### Setup Instructions

1. Configure the required IAM role:

```bash
# Run the setup script
cd scripts
./aws_fis_setup.sh
```

This script:
- Creates the necessary IAM roles
- Sets up CloudWatch alarms for stop conditions
- Creates your first experiment template

## Available Experiment Templates

The following experiment templates are available:

| Template | File | Description |
|----------|------|-------------|
| ECS Task Failure | [ecs_task_failure.json](../scripts/fis_templates/ecs_task_failure.json) | Terminates random ECS tasks to test service recovery |
| EC2 CPU Stress | [ec2_cpu_stress.json](../scripts/fis_templates/ec2_cpu_stress.json) | Stresses CPU on EC2 instances to test scaling and performance degradation |

To use a custom template:

```bash
# Update account ID and region
sed -i 's/ACCOUNT_ID/123456789012/g' scripts/fis_templates/ecs_task_failure.json
sed -i 's/REGION/eu-west-2/g' scripts/fis_templates/ecs_task_failure.json

# Create the template
aws fis create-experiment-template --cli-input-json file://scripts/fis_templates/ecs_task_failure.json
```

## Running Experiments

Use the provided script to run and monitor experiments:

```bash
# Run an experiment with a specific template ID
./scripts/run_fis_experiment.sh -t exp-1234abcd

# Additional options
./scripts/run_fis_experiment.sh -t exp-1234abcd -i 15 -m 1800
```

Options:
- `-t, --template-id`: Experiment template ID (required)
- `-k, --tag-key`: Tag key (default: Purpose)
- `-v, --tag-value`: Tag value (default: Resilience-Testing)
- `-i, --interval`: Monitoring interval in seconds (default: 30)
- `-m, --max-time`: Maximum runtime in seconds (default: 3600)

## Monitoring and Dashboards

### CloudWatch Dashboard

A CloudWatch dashboard template is provided in `scripts/cloudwatch_fis_dashboard.json`. To create the dashboard:

1. Update placeholders in the JSON file:
   - `${ClusterName}`: Your ECS cluster name
   - `${ASGName}`: Your Auto Scaling group name
   - `${LoadBalancerName}`: Your ALB name
   - `${DBInstanceName}`: Your RDS instance name
   - `${ServiceName}`: Your ECS service name
   - `${DesiredTaskCount}`: Desired task count in your ECS service
   - `${ExperimentId}`: Your FIS experiment ID
   - `${ExperimentStartTime}` and `${ExperimentEndTime}`: Experiment timestamps

2. Create the dashboard:

```bash
aws cloudwatch put-dashboard \
  --dashboard-name FIS-Experiment-Dashboard \
  --dashboard-body file://scripts/cloudwatch_fis_dashboard.json
```

### Metrics to Monitor

During experiments, focus on these key metrics:
- ECS task count and service health
- Application error rates and response times
- System resource utilization
- Database performance and connections
- Network latency and packet loss

## Reporting

After each experiment, generate a comprehensive report using the provided template:

1. Copy the template: `cp docs/templates/fis_experiment_report_template.md docs/reports/fis-experiment-YYYY-MM-DD.md`
2. Fill in experiment details and observations
3. Share with relevant stakeholders
4. Update runbooks based on findings

## Best Practices

1. **Start Small**: Begin with minimal-impact experiments in development environments
2. **Proper Scoping**: Target specific components with clear hypotheses
3. **Safety First**: Always include stop conditions to abort experiments if needed
4. **Incremental Complexity**: Gradually increase experiment complexity
5. **Documentation**: Document all experiments, results, and learnings
6. **Team Communication**: Notify all stakeholders before running experiments
7. **Scheduled Experiments**: Run experiments regularly as part of resilience testing

## Troubleshooting

### Common Issues

1. **Experiment won't start**
   - Check IAM role permissions
   - Verify resource tags match experiment template
   - Ensure resources exist in the target environment

2. **Experiment fails immediately**
   - Check CloudTrail logs for permission errors
   - Verify target resource existence
   - Validate experiment template syntax

3. **Stop conditions trigger too quickly**
   - Adjust CloudWatch alarm thresholds
   - Create more specific alarms for experiments
   - Check for pre-existing issues in the environment

4. **Experiment doesn't affect resources**
   - Verify resource targeting (tags, ARNs)
   - Check that action is supported for the resource type
   - Validate IAM permissions for specific actions

### Support Resources

- [AWS FIS Documentation](https://docs.aws.amazon.com/fis/)
- [AWS FIS API Reference](https://docs.aws.amazon.com/fis/latest/APIReference/)
- [AWS FIS CloudFormation Reference](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/AWS_FIS.html)