# Automated Disaster Recovery Architecture

This document explains our automated DR failover architecture using Route 53 and AWS Lambda.

## Architecture Overview

The DR solution is based on a "Pilot Light" approach, where a minimal version of the environment runs in the DR region. When a failover occurs, this environment automatically scales up to handle production traffic.

### Key Components:

1. **Route 53 Health Checks**:
   - Continuously monitor the primary region's health
   - Trigger automated failover when primary region is unhealthy

2. **DNS Failover**:
   - Route 53 DNS records automatically redirect traffic to DR region
   - No manual intervention required

3. **Lambda Auto-Scaling**:
   - AWS Lambda function automatically scales up the DR environment
   - Transitions from spot instances to on-demand instances for reliability
   - Increases ECS service desired count to handle production traffic

4. **Database Replication**:
   - Continuous database replication from primary to DR region
   - Ensures data consistency during failover

5. **Monthly Testing**:
   - Scheduled test failover runs during off-peak hours (Sunday after midnight)
   - Test lasts for 1 hour, then automatically restores to pilot light mode
   - Validates DR readiness without manual intervention

## Failover Process

1. **Primary Region Health Check Fails**:
   - Route 53 detects unavailability of the primary region
   - CloudWatch alarm changes to ALARM state

2. **Automated Failover Triggers**:
   - Route 53 updates DNS to point to DR region
   - SNS notification triggers Lambda function

3. **DR Environment Scales Up**:
   - Lambda increases ECS service desired count
   - Lambda updates ASG to use on-demand instances instead of spot
   - Application traffic is served from the DR region

4. **Database Failover**:
   - RDS replica in DR region is already synchronized
   - Application immediately connects to the DR database

5. **Post-Failover**:
   - Application continues to run in DR region
   - After primary region is restored, manual failback can be initiated

## Monthly DR Testing

The system is configured to automatically test the DR failover process every month:

1. **Test Schedule**:
   - First Monday of each month at 00:05 AM UTC
   - Timing chosen to minimize impact on production traffic

2. **Test Process**:
   - Lambda function is triggered by CloudWatch Events
   - DR environment scales up as in a real failover
   - Test runs for 1 hour
   - System automatically scales back to pilot light mode

3. **Test Monitoring**:
   - CloudWatch metrics track test performance
   - SNS notifications sent at start and end of test

## Advantages of This Architecture

1. **Fully Automated Failover**:
   - No manual intervention required during an outage
   - Rapid response to region-level failures

2. **Cost-Efficient**:
   - Pilot light approach minimizes costs during normal operation
   - Uses spot instances for the pilot light environment
   - Scales only when needed

3. **Reliability**:
   - Monthly testing ensures DR readiness
   - Automatic switch to on-demand instances during failover for reliability
   - Built-in monitoring and alerting

4. **Data Consistency**:
   - Continuous database replication ensures minimal data loss
   - Automatic promotion of read replica during failover

## Implementation Details

The DR solution is implemented using the following Terraform modules:

1. **route53-failover**: Manages Route 53 health checks and DNS failover
2. **dr-lambda**: Contains Lambda functions for auto-scaling during failover
3. **ecs**: Deploys ECS cluster in pilot light mode and handles scaling
4. **database**: Manages RDS instances with cross-region replication

Configuration variables in `environments/dr-pilot-light/terraform.tfvars` control the behavior of the failover process, including scaling parameters and timing of monthly tests.