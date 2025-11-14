# AWS Fault Injection Simulator (FIS) Playbook - Dev Environment

## Introduction

This playbook outlines how to use AWS Fault Injection Simulator (FIS) to conduct controlled chaos engineering experiments in the **development environment** of our infrastructure. The goal is to validate the resilience of our application and infrastructure components without affecting production workloads.

## 1. Prerequisites

### 1.1 Required Permissions

Before implementing AWS FIS experiments in the dev environment, ensure you have the following IAM permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "fis:*",
                "ecs:*",
                "ec2:*",
                "rds:*",
                "cloudwatch:*",
                "sns:*"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:RequestedRegion": "us-east-1"
                }
            }
        }
    ]
}
```

### 1.2 Environment Setup

Verify the following dev environment components are deployed and healthy:

- ECS Cluster: `project-dev-cluster`
- ECS Service: `project-dev-service`
- EC2 instances in the ECS cluster
- RDS database instance
- CloudWatch monitoring and alarms

### 1.3 Safe Experimentation Parameters

For the dev environment, configure the following parameters to ensure experiments are contained:

```bash
# Environment identifier to limit experiments
ENVIRONMENT=dev

# Ensure experiments target only dev resources
RESOURCE_TAGS="Environment=dev"

# Maximum duration for experiments (dev-specific)
MAX_DURATION=30m

# Automatic stop conditions
CPU_THRESHOLD=90
MEMORY_THRESHOLD=90
```

## 2. AWS FIS Experiment Types for Dev Environment

### 2.1 EC2 Instance Experiments

#### 2.1.1 CPU Stress Test

```json
{
    "description": "Stress CPU on EC2 instances in dev environment",
    "targets": {
        "ec2-instances": {
            "resourceType": "aws:ec2:instance",
            "resourceTags": {
                "Environment": "dev"
            },
            "selectionMode": "COUNT(1)"
        }
    },
    "actions": {
        "stress-cpu": {
            "actionId": "aws:ssm:send-command",
            "parameters": {
                "documentArn": "arn:aws:ssm:us-east-1::document/AWSFIS-Run-CPU-Stress",
                "documentParameters": "{\"DurationSeconds\":\"300\", \"CPU\":\"0\"}"
            },
            "targets": {
                "Instances": "ec2-instances"
            }
        }
    },
    "stopConditions": [
        {
            "source": "aws:cloudwatch:alarm",
            "value": "arn:aws:cloudwatch:us-east-1:111122223333:alarm:project-dev-cpu-high"
        }
    ],
    "roleArn": "arn:aws:iam::111122223333:role/FisServiceRole",
    "tags": {
        "Name": "dev-cpu-stress-test"
    }
}
```

#### 2.1.2 Memory Pressure Test

```json
{
    "description": "Stress Memory on EC2 instances in dev environment",
    "targets": {
        "ec2-instances": {
            "resourceType": "aws:ec2:instance",
            "resourceTags": {
                "Environment": "dev"
            },
            "selectionMode": "COUNT(1)"
        }
    },
    "actions": {
        "stress-memory": {
            "actionId": "aws:ssm:send-command",
            "parameters": {
                "documentArn": "arn:aws:ssm:us-east-1::document/AWSFIS-Run-Memory-Stress",
                "documentParameters": "{\"DurationSeconds\":\"300\", \"MemoryPercent\":\"80\"}"
            },
            "targets": {
                "Instances": "ec2-instances"
            }
        }
    },
    "stopConditions": [
        {
            "source": "aws:cloudwatch:alarm",
            "value": "arn:aws:cloudwatch:us-east-1:111122223333:alarm:project-dev-memory-high"
        }
    ],
    "roleArn": "arn:aws:iam::111122223333:role/FisServiceRole",
    "tags": {
        "Name": "dev-memory-stress-test"
    }
}
```

#### 2.1.3 Network Latency Test

```json
{
    "description": "Inject network latency on EC2 instances in dev environment",
    "targets": {
        "ec2-instances": {
            "resourceType": "aws:ec2:instance",
            "resourceTags": {
                "Environment": "dev"
            },
            "selectionMode": "COUNT(1)"
        }
    },
    "actions": {
        "network-latency": {
            "actionId": "aws:ssm:send-command",
            "parameters": {
                "documentArn": "arn:aws:ssm:us-east-1::document/AWSFIS-Run-Network-Latency",
                "documentParameters": "{\"DurationSeconds\":\"300\", \"DelayMilliseconds\":\"100\", \"Interface\":\"eth0\"}"
            },
            "targets": {
                "Instances": "ec2-instances"
            }
        }
    },
    "stopConditions": [
        {
            "source": "aws:cloudwatch:alarm",
            "value": "arn:aws:cloudwatch:us-east-1:111122223333:alarm:project-dev-latency-high"
        }
    ],
    "roleArn": "arn:aws:iam::111122223333:role/FisServiceRole",
    "tags": {
        "Name": "dev-network-latency-test"
    }
}
```

### 2.2 ECS Service Experiments

#### 2.2.1 Task Termination Test

```json
{
    "description": "Terminate ECS tasks in dev environment",
    "targets": {
        "ecs-tasks": {
            "resourceType": "aws:ecs:task",
            "resourceTags": {
                "Environment": "dev"
            },
            "selectionMode": "COUNT(1)",
            "parameters": {
                "cluster": "project-dev-cluster",
                "service": "project-dev-service"
            }
        }
    },
    "actions": {
        "terminate-tasks": {
            "actionId": "aws:ecs:stop-task",
            "parameters": {
                "reason": "FIS experiment"
            },
            "targets": {
                "tasks": "ecs-tasks"
            }
        }
    },
    "stopConditions": [
        {
            "source": "aws:cloudwatch:alarm",
            "value": "arn:aws:cloudwatch:us-east-1:111122223333:alarm:project-dev-task-count-low"
        }
    ],
    "roleArn": "arn:aws:iam::111122223333:role/FisServiceRole",
    "tags": {
        "Name": "dev-task-termination-test"
    }
}
```

### 2.3 RDS Experiments (Optional - Use with Caution)

#### 2.3.1 RDS CPU Pressure Test

```json
{
    "description": "Stress CPU on RDS instance in dev environment",
    "targets": {
        "rds-instances": {
            "resourceType": "aws:rds:db",
            "resourceTags": {
                "Environment": "dev"
            },
            "selectionMode": "ALL"
        }
    },
    "actions": {
        "stress-cpu": {
            "actionId": "aws:rds:force-failover",
            "targets": {
                "databases": "rds-instances"
            }
        }
    },
    "stopConditions": [
        {
            "source": "aws:cloudwatch:alarm",
            "value": "arn:aws:cloudwatch:us-east-1:111122223333:alarm:project-dev-db-cpu-high"
        }
    ],
    "roleArn": "arn:aws:iam::111122223333:role/FisServiceRole",
    "tags": {
        "Name": "dev-rds-failover-test"
    }
}
```

## 3. Implementation Steps for Dev Environment

### 3.1 Create FIS Service Role

```bash
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

# Attach policies to the role
aws iam attach-role-policy \
    --role-name FisServiceRole-Dev \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSFaultInjectionSimulatorEC2Access
    
aws iam attach-role-policy \
    --role-name FisServiceRole-Dev \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSFaultInjectionSimulatorECSAccess
```

### 3.2 Create CloudWatch Alarms for Stop Conditions

```bash
# Create CPU high alarm for experiment stop condition
aws cloudwatch put-metric-alarm \
    --alarm-name project-dev-cpu-high \
    --alarm-description "High CPU alarm for FIS experiments" \
    --metric-name CPUUtilization \
    --namespace AWS/ECS \
    --statistic Average \
    --period 60 \
    --threshold 90 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --dimensions Name=ClusterName,Value=project-dev-cluster Name=ServiceName,Value=project-dev-service

# Create Task count low alarm for experiment stop condition
aws cloudwatch put-metric-alarm \
    --alarm-name project-dev-task-count-low \
    --alarm-description "Task count low alarm for FIS experiments" \
    --metric-name RunningTaskCount \
    --namespace AWS/ECS \
    --statistic Average \
    --period 60 \
    --threshold 1 \
    --comparison-operator LessThanThreshold \
    --evaluation-periods 1 \
    --dimensions Name=ClusterName,Value=project-dev-cluster Name=ServiceName,Value=project-dev-service
```

### 3.3 Create and Run Your First FIS Experiment

```bash
# Create an experiment template
aws fis create-experiment-template \
    --cli-input-json file://scripts/fis_templates/dev_cpu_stress.json

# Start the experiment
aws fis start-experiment \
    --experiment-template-id YOUR_TEMPLATE_ID \
    --tags Key=Name,Value=FirstDevExperiment
```

### 3.4 Monitor Experiment Status

```bash
# Get experiment status
aws fis get-experiment \
    --id YOUR_EXPERIMENT_ID
```

## 4. Monitoring and Analysis

### 4.1 CloudWatch Dashboard for Dev FIS Experiments

Create a dedicated CloudWatch dashboard for monitoring FIS experiments in the dev environment:

```bash
aws cloudwatch put-dashboard \
    --dashboard-name DevFISExperiments \
    --dashboard-body file://scripts/cloudwatch/dev_fis_dashboard.json
```

### 4.2 Key Metrics to Monitor During Experiments

For the dev environment, focus on:

- ECS service task count (should recover after termination)
- EC2 CPU and Memory utilization
- Load balancer error rates
- Response times
- Auto-scaling activities

### 4.3 Post-Experiment Analysis

After each experiment:

1. Gather metrics data from CloudWatch
2. Review any alarms that triggered
3. Document recovery time
4. Identify potential improvements to architecture
5. Update application or infrastructure as needed
6. Document findings in experiment report

## 5. Integrating with CI/CD

### 5.1 Schedule Regular FIS Tests in Dev

To integrate with the existing Jenkins pipeline, create a scheduled job:

```groovy
pipeline {
    agent any
    
    triggers {
        // Run weekly on Fridays
        cron('0 0 * * 5')
    }
    
    stages {
        stage('Run FIS Experiments') {
            when {
                expression {
                    return env.BRANCH_NAME == 'develop'
                }
            }
            steps {
                sh 'aws fis start-experiment --experiment-template-id ${FIS_TEMPLATE_ID} --tags Key=Name,Value=WeeklyDevTest'
                
                // Wait for experiment to complete
                sh 'scripts/wait_for_experiment.sh ${FIS_EXPERIMENT_ID}'
                
                // Generate report
                sh 'scripts/generate_fis_report.sh ${FIS_EXPERIMENT_ID}'
            }
        }
    }
}
```

### 5.2 Automate Resilience Testing with FIS

Create automated tests that verify the system can recover from the injected failures:

```bash
#!/bin/bash

# Run FIS experiment
EXPERIMENT_ID=$(aws fis start-experiment --experiment-template-id $TEMPLATE_ID --query experiment.id --output text)

# Wait for experiment to start
aws fis wait experiment-started --id $EXPERIMENT_ID

# Monitor application health
FAILURES=0
for i in {1..10}; do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://app-dev.example.com/health)
  if [ "$HTTP_STATUS" -ne 200 ]; then
    FAILURES=$((FAILURES+1))
  fi
  sleep 30
done

# Wait for experiment to complete
aws fis wait experiment-completed --id $EXPERIMENT_ID

# Check results
echo "Health check failures: $FAILURES out of 10"
if [ "$FAILURES" -gt 3 ]; then
  echo "Too many health check failures during the experiment!"
  exit 1
fi

# Get experiment results
aws fis get-experiment --id $EXPERIMENT_ID
```

## 6. Best Practices for FIS in Dev

1. **Start Small**: Begin with simple experiments that affect only a small portion of resources
2. **Limit Blast Radius**: Always use targetResourceTags to ensure only dev environment is affected
3. **Add Safety Mechanisms**: Always implement stop conditions to prevent runaway experiments
4. **Document Everything**: Keep detailed records of all experiments and their results
5. **Learn Iteratively**: Use learnings from each experiment to improve application and infrastructure
6. **Test Before Production**: Perfect your FIS experiments in dev before considering production tests
7. **Coordinate with Team**: Schedule experiments when team members are available to monitor and respond

## 7. Conclusion

This playbook provides a structured approach to implementing AWS Fault Injection Simulator in your dev environment. By regularly running these experiments and learning from the results, you can build a more resilient application and infrastructure that better withstands real-world failures.

Remember that chaos engineering is an iterative process - start small, learn, and gradually increase the complexity of your experiments as your confidence grows.