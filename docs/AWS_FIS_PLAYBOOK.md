# AWS Fault Injection Simulator (FIS) Playbook

This playbook provides a comprehensive guide for implementing and executing chaos engineering experiments using AWS Fault Injection Simulator (FIS) for the ECS/EC2/Jenkins infrastructure. AWS FIS allows you to perform controlled chaos engineering experiments to improve resilience and performance.

## 1. Introduction to AWS FIS

### 1.1. What is AWS Fault Injection Simulator?
AWS Fault Injection Simulator (FIS) is a fully managed service that enables you to perform fault injection experiments on your AWS workloads. FIS simplifies the process of creating controlled experiments that help you observe how your application responds to various types of failures.

### 1.2. Key Benefits
- **Controlled Testing**: Run chaos experiments with safety guardrails
- **AWS Integration**: Native integration with AWS services
- **Targeted Actions**: Precisely target specific resources
- **Managed Service**: No infrastructure to maintain
- **Improved Resilience**: Identify and fix weaknesses before they impact production

## 2. Prerequisites

### 2.1. IAM Permissions
Create an IAM role with appropriate permissions for FIS:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "fis:*"
      ],
      "Resource": "*"
    },
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
        "elasticache:RebootCacheCluster"
      ],
      "Resource": "*"
    }
  ]
}
```

### 2.2. Service Quotas
- Verify service quotas for AWS FIS in your account
- Default quotas:
  - 5 concurrent experiments per account 
  - 20 experiment templates per account

### 2.3. CloudWatch Alarms for Stop Conditions
Create CloudWatch alarms to act as stop conditions for experiments:

```
Experiment Stop Conditions:
- Application Error Rate > 5%
- API Response Time > 2 seconds
- CPU Utilization > 80%
```

## 3. Experiment Templates for ECS/EC2/Jenkins Infrastructure

### 3.1. EC2 Instance Experiments

#### 3.1.1. EC2 Instance Stress Test
```json
{
  "experimentTemplate": {
    "description": "CPU stress test on EC2 instances",
    "targets": {
      "ec2-instances": {
        "resourceType": "aws:ec2:instance",
        "resourceTags": {
          "Environment": "dev",
          "Service": "ecs-cluster"
        },
        "selectionMode": "COUNT(1)"
      }
    },
    "actions": {
      "stress-cpu": {
        "actionId": "aws:ec2:stress-cpu",
        "parameters": {
          "duration": "PT5M"
        },
        "targets": {
          "Instances": "ec2-instances"
        }
      }
    },
    "stopConditions": [
      {
        "source": "aws:cloudwatch:alarm",
        "value": "arn:aws:cloudwatch:REGION:ACCOUNT_ID:alarm:HighCPUAlarm"
      }
    ],
    "roleArn": "arn:aws:iam::ACCOUNT_ID:role/FISExecutionRole",
    "tags": {
      "Name": "EC2-CPU-Stress-Test"
    }
  }
}
```

#### 3.1.2. EC2 Instance Termination
```json
{
  "experimentTemplate": {
    "description": "Terminate EC2 instance in ECS cluster", 
    "targets": {
      "ec2-instances": {
        "resourceType": "aws:ec2:instance",
        "resourceTags": {
          "Environment": "dev",
          "Service": "ecs-cluster"
        },
        "selectionMode": "COUNT(1)"
      }
    },
    "actions": {
      "terminate-instance": {
        "actionId": "aws:ec2:terminate-instances",
        "targets": {
          "Instances": "ec2-instances"
        }
      }
    },
    "stopConditions": [
      {
        "source": "aws:cloudwatch:alarm",
        "value": "arn:aws:cloudwatch:REGION:ACCOUNT_ID:alarm:ServiceHealthAlarm"
      }
    ],
    "roleArn": "arn:aws:iam::ACCOUNT_ID:role/FISExecutionRole",
    "tags": {
      "Name": "EC2-Instance-Termination-Test"
    }
  }
}
```

### 3.2. ECS Service Experiments

#### 3.2.1. ECS Task Termination
```json
{
  "experimentTemplate": {
    "description": "Terminate random ECS tasks",
    "targets": {
      "ecs-tasks": {
        "resourceType": "aws:ecs:task",
        "resourceArns": ["arn:aws:ecs:REGION:ACCOUNT_ID:task/your-cluster/*"],
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
        "value": "arn:aws:cloudwatch:REGION:ACCOUNT_ID:alarm:ECSServiceHealthAlarm"
      }
    ],
    "roleArn": "arn:aws:iam::ACCOUNT_ID:role/FISExecutionRole",
    "tags": {
      "Name": "ECS-Task-Termination-Test"
    }
  }
}
```

#### 3.2.2. ECS Cluster CPU Stress
```json
{
  "experimentTemplate": {
    "description": "CPU stress on ECS tasks",
    "targets": {
      "ecs-tasks": {
        "resourceType": "aws:ecs:task",
        "resourceArns": ["arn:aws:ecs:REGION:ACCOUNT_ID:task/your-cluster/*"],
        "selectionMode": "PERCENT(50)"
      }
    },
    "actions": {
      "stress-tasks": {
        "actionId": "aws:ssm:send-command",
        "parameters": {
          "documentArn": "arn:aws:ssm:REGION::document/AWSFIS-Run-CPU-Stress",
          "documentParameters": "{\"DurationSeconds\":\"300\"}"
        },
        "targets": {
          "Tasks": "ecs-tasks"
        }
      }
    },
    "stopConditions": [
      {
        "source": "aws:cloudwatch:alarm",
        "value": "arn:aws:cloudwatch:REGION:ACCOUNT_ID:alarm:ECSHighCPUAlarm"
      }
    ],
    "roleArn": "arn:aws:iam::ACCOUNT_ID:role/FISExecutionRole",
    "tags": {
      "Name": "ECS-CPU-Stress-Test"
    }
  }
}
```

### 3.3. Database Experiments

#### 3.3.1. RDS Failover Test
```json
{
  "experimentTemplate": {
    "description": "Force RDS Multi-AZ failover",
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
      "failover-rds": {
        "actionId": "aws:rds:failover-db-cluster",
        "targets": {
          "Clusters": "rds-instances"
        }
      }
    },
    "stopConditions": [
      {
        "source": "aws:cloudwatch:alarm",
        "value": "arn:aws:cloudwatch:REGION:ACCOUNT_ID:alarm:DatabaseFailureAlarm"
      }
    ],
    "roleArn": "arn:aws:iam::ACCOUNT_ID:role/FISExecutionRole",
    "tags": {
      "Name": "RDS-Failover-Test"
    }
  }
}
```

### 3.4. Network Experiments

#### 3.4.1. Network Latency Test
```json
{
  "experimentTemplate": {
    "description": "Introduce network latency",
    "targets": {
      "ec2-instances": {
        "resourceType": "aws:ec2:instance",
        "resourceTags": {
          "Environment": "dev",
          "Service": "ecs-cluster"
        },
        "selectionMode": "PERCENT(30)"
      }
    },
    "actions": {
      "add-latency": {
        "actionId": "aws:network:disrupt-connectivity",
        "parameters": {
          "duration": "PT5M",
          "delayMilliseconds": "200",
          "jitterMilliseconds": "50"
        },
        "targets": {
          "Instances": "ec2-instances"
        }
      }
    },
    "stopConditions": [
      {
        "source": "aws:cloudwatch:alarm",
        "value": "arn:aws:cloudwatch:REGION:ACCOUNT_ID:alarm:ServiceLatencyAlarm"
      }
    ],
    "roleArn": "arn:aws:iam::ACCOUNT_ID:role/FISExecutionRole",
    "tags": {
      "Name": "Network-Latency-Test"
    }
  }
}
```

#### 3.4.2. Network Packet Loss Test
```json
{
  "experimentTemplate": {
    "description": "Introduce network packet loss",
    "targets": {
      "ec2-instances": {
        "resourceType": "aws:ec2:instance",
        "resourceTags": {
          "Environment": "dev",
          "Service": "ecs-cluster"
        },
        "selectionMode": "PERCENT(30)"
      }
    },
    "actions": {
      "packet-loss": {
        "actionId": "aws:network:disrupt-connectivity",
        "parameters": {
          "duration": "PT5M",
          "lossPercent": "5"
        },
        "targets": {
          "Instances": "ec2-instances"
        }
      }
    },
    "stopConditions": [
      {
        "source": "aws:cloudwatch:alarm",
        "value": "arn:aws:cloudwatch:REGION:ACCOUNT_ID:alarm:ServiceHealthAlarm"
      }
    ],
    "roleArn": "arn:aws:iam::ACCOUNT_ID:role/FISExecutionRole",
    "tags": {
      "Name": "Network-Packet-Loss-Test"
    }
  }
}
```

### 3.5. Jenkins CI/CD Pipeline Experiments

#### 3.5.1. Jenkins Instance Disruption
```json
{
  "experimentTemplate": {
    "description": "Disrupt Jenkins server instance", 
    "targets": {
      "jenkins-instance": {
        "resourceType": "aws:ec2:instance",
        "resourceTags": {
          "Service": "jenkins"
        },
        "selectionMode": "ALL"
      }
    },
    "actions": {
      "reboot-jenkins": {
        "actionId": "aws:ec2:reboot-instances",
        "targets": {
          "Instances": "jenkins-instance"
        }
      }
    },
    "stopConditions": [
      {
        "source": "aws:cloudwatch:alarm",
        "value": "arn:aws:cloudwatch:REGION:ACCOUNT_ID:alarm:JenkinsHealthAlarm"
      }
    ],
    "roleArn": "arn:aws:iam::ACCOUNT_ID:role/FISExecutionRole",
    "tags": {
      "Name": "Jenkins-Disruption-Test"
    }
  }
}
```

### 3.6. ElastiCache Experiments

#### 3.6.1. ElastiCache Node Failover
```json
{
  "experimentTemplate": {
    "description": "Force ElastiCache node failover",
    "targets": {
      "cache-nodes": {
        "resourceType": "aws:elasticache:cache-cluster",
        "resourceTags": {
          "Environment": "dev"
        },
        "selectionMode": "COUNT(1)"
      }
    },
    "actions": {
      "reboot-cache": {
        "actionId": "aws:elasticache:reboot-cache-cluster",
        "targets": {
          "CacheClusters": "cache-nodes"
        }
      }
    },
    "stopConditions": [
      {
        "source": "aws:cloudwatch:alarm",
        "value": "arn:aws:cloudwatch:REGION:ACCOUNT_ID:alarm:CacheFailureAlarm"
      }
    ],
    "roleArn": "arn:aws:iam::ACCOUNT_ID:role/FISExecutionRole",
    "tags": {
      "Name": "ElastiCache-Node-Failover-Test"
    }
  }
}
```

## 4. Experiment Execution Workflow

### 4.1. Pre-Experiment Preparation
1. **Notification Setup**:
   ```
   - Create dedicated SNS topic for FIS experiments
   - Subscribe relevant team members
   - Configure CloudWatch Events to push FIS events to SNS
   ```

2. **Baseline Metrics Collection**:
   ```
   - Record baseline performance metrics
   - Set up enhanced metric collection during experiment
   - Create dashboards for experiment monitoring
   ```

3. **Rollback Plan**:
   ```
   - Document rollback steps for each experiment
   - Create automation scripts for emergency rollback if needed
   - Test rollback procedures
   ```

### 4.2. Experiment Execution Steps

1. **Safety Check**:
   ```
   - Review experiment parameters and targets
   - Verify stop conditions are properly configured
   - Ensure experiment role has proper permissions
   - Confirm notification channels are working
   ```

2. **Execute Experiment**:
   ```bash
   # Using AWS CLI to start an experiment
   aws fis start-experiment \
     --experiment-template-id "YOUR_TEMPLATE_ID" \
     --tags "Purpose=Resilience-Testing"
   ```

3. **Monitor Experiment**:
   ```
   - Access CloudWatch dashboards for real-time metrics
   - Monitor application health and performance
   - Check experiment progress in FIS console
   - Document any unexpected behaviors
   ```

4. **Post-Experiment Analysis**:
   ```
   - Collect metrics from experiment window
   - Compare with baseline measurements
   - Document recovery times and any failures
   - Identify areas for improvement
   ```

### 4.3. Experiment Result Documentation Template
```
Experiment ID: [ID]
Template Used: [Template Name]
Date/Time: [Execution Time]
Duration: [Duration]
Target Resources: [List of affected resources]

Results:
- System Recovery Time: [Time]
- Unexpected Behaviors: [Description]
- Failed Components: [List]
- Successful Mitigations: [List]

Performance Impact:
- Latency Increase: [Percentage]
- Error Rate Change: [Percentage]
- Resource Utilization: [Metrics]

Lessons Learned:
- [Key findings]
- [Improvement opportunities]

Actions Items:
- [List of follow-up tasks]
```

## 5. AWS FIS Integration with Existing Infrastructure

### 5.1. Integration with CloudWatch
1. **Create Custom Metrics for Experiments**:
   ```
   - Recovery time metric
   - Failure impact metric
   - Service degradation metric
   ```

2. **Experiment-Specific Dashboards**:
   ```
   - Create FIS experiment dashboard
   - Include service health indicators
   - Add experiment timeline markers
   ```

### 5.2. Integration with EventBridge
1. **Event Pattern for FIS Events**:
   ```json
   {
     "source": ["aws.fis"],
     "detail-type": ["AWS FIS Experiment State Change"],
     "detail": {
       "state": ["RUNNING", "COMPLETED", "FAILED", "STOPPED"]
     }
   }
   ```

2. **Auto-Remediation Rules**:
   ```
   - Create EventBridge rules to trigger Lambda functions
   - Implement automated recovery for critical services
   - Log all experiment events for analysis
   ```

### 5.3. Integration with AWS Systems Manager
1. **SSM Documents for Complex Experiments**:
   ```
   - Create SSM documents for custom fault scenarios
   - Include pre and post-checks in SSM workflows
   - Combine with FIS for enhanced testing capabilities
   ```

## 6. Testing Schedule

### 6.1. Progressive Testing Approach
1. **Stage 1: Basic Component Tests**
   ```
   - Single EC2 instance stress tests
   - Individual ECS task termination
   - Simple network latency tests
   ```

2. **Stage 2: Service-Level Tests**
   ```
   - Multiple component failures
   - Database failover tests
   - Service dependency tests
   ```

3. **Stage 3: Complex Scenario Tests**
   ```
   - Region availability disruption
   - Full AZ failure simulation
   - Combined infrastructure and application failures
   ```

### 6.2. Environment-Specific Testing

1. **Development Environment**:
   ```
   - Regular testing (weekly)
   - Aggressive scenarios permitted
   - Full component failure allowed
   ```

2. **Staging/Pre-Production**:
   ```
   - Scheduled testing (bi-weekly)
   - Moderate scenarios
   - Service degradation but not complete failure
   ```

3. **Production Environment**:
   ```
   - Limited testing (monthly)
   - Conservative scenarios
   - Strict guardrails required
   - Higher approval process
   ```

## 7. Security Considerations

### 7.1. IAM Permission Boundaries
- Create service-specific roles with least privilege
- Implement permission boundaries for FIS roles
- Regularly audit FIS permissions

### 7.2. Experiment Template Security
- Store experiment templates in version control
- Require peer review for template changes
- Scan templates for security issues before use

### 7.3. Stop Condition Best Practices
- Always include multiple stop conditions
- Include global service health metrics
- Set conservative thresholds for production

## 8. Best Practices for AWS FIS

### 8.1. General Best Practices
- Start with small experiments and gradually increase complexity
- Always run experiments in lower environments before production
- Document and share results with all stakeholders
- Update runbooks based on learnings

### 8.2. Resource Targeting Best Practices
- Use resource tagging for precise targeting
- Prefer percentage-based selection in production 
- Use COUNT(1) for initial validation
- Always exclude critical infrastructure components

### 8.3. Experiment Design Best Practices
- Design experiments based on real-world scenarios
- Focus on one failure mode per experiment
- Test recovery mechanisms, not just failures
- Combine FIS with Game Days for team learning

## 9. Integration with Resilience Testing Program

### 9.1. Relationship with Existing Resilience Testing
- AWS FIS experiments complement existing tests
- Use FIS for automated execution of scenarios in the resilience playbook
- Convert manual tests to FIS templates where possible

### 9.2. Comparative Analysis
- Compare manual vs. FIS test results
- Document differences in recovery times
- Identify gaps in resilience testing coverage

## 10. Implementation Roadmap

### 10.1. Phase 1: Foundation (Weeks 1-2)
- Set up IAM roles and permissions
- Create CloudWatch alarms for stop conditions
- Develop basic experiment templates
- Test in development environment

### 10.2. Phase 2: Expansion (Weeks 3-4)
- Create advanced experiment templates
- Integrate with monitoring and notification systems
- Develop experiment execution procedures
- Test in staging environment

### 10.3. Phase 3: Production Integration (Weeks 5-8)
- Develop production safeguards
- Create production-ready templates
- Schedule initial production experiments
- Develop automation for experiment analysis

### 10.4. Phase 4: Continuous Improvement (Ongoing)
- Regular experiment schedule
- Template library expansion
- Results analysis and system hardening
- Integration with CI/CD pipeline for automated resilience testing

## Appendix A: AWS FIS API Reference

### A.1. Key CLI Commands
```bash
# List experiment templates
aws fis list-experiment-templates

# Create experiment template
aws fis create-experiment-template --cli-input-json file://template.json

# Start experiment
aws fis start-experiment --experiment-template-id "YOUR_TEMPLATE_ID"

# Stop experiment
aws fis stop-experiment --id "EXPERIMENT_ID" --reason "Manual stop"

# Get experiment details
aws fis get-experiment --id "EXPERIMENT_ID"
```

## Appendix B: CloudWatch Alarm Configuration

### B.1. Example Alarm for Experiment Stop Condition
```json
{
  "AlarmName": "FIS-ExperimentStopCondition",
  "AlarmDescription": "Stop FIS experiment if error rate exceeds threshold",
  "MetricName": "5XXError",
  "Namespace": "AWS/ApplicationELB",
  "Statistic": "Sum",
  "Dimensions": [
    {
      "Name": "LoadBalancer",
      "Value": "app/your-alb/1234567890abcdef"
    }
  ],
  "Period": 60,
  "EvaluationPeriods": 2,
  "Threshold": 5,
  "ComparisonOperator": "GreaterThanThreshold",
  "TreatMissingData": "notBreaching"
}
```

## Appendix C: Troubleshooting Guide

### C.1. Common Issues and Resolutions

#### Experiment Won't Start
1. **Check IAM permissions**: Verify role has proper permissions
2. **Resource targeting**: Confirm resources exist with specified tags
3. **Service quotas**: Check if you've hit the concurrent experiment limit

#### Experiment Not Affecting Resources
1. **Verify resource selection**: Check if correct resources are being targeted
2. **Check experiment logs**: Look for errors in CloudTrail or FIS experiment logs
3. **Verify action support**: Confirm the resource type supports the action

#### Experiment Won't Stop
1. **Check CloudWatch alarms**: Verify alarms are correctly configured
2. **Manual stop**: Use stop-experiment API call
3. **Emergency procedure**: Follow emergency runbook for manual resource recovery

## Appendix D: Additional Resources

- [AWS FIS Documentation](https://docs.aws.amazon.com/fis/)
- [AWS FIS Workshop](https://catalog.workshops.aws/fault-injection-simulator)
- [Chaos Engineering Principles](https://principlesofchaos.org/)
- [AWS FIS Blog Posts](https://aws.amazon.com/blogs/aws/aws-fault-injection-simulator-use-controlled-experiments-to-boost-resilience/)