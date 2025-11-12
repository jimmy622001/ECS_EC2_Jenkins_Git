terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_lambda_function" "dr_scale_up" {
  function_name = "${var.name_prefix}-dr-scale-up"
  role          = aws_iam_role.dr_lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs16.x"
  timeout       = 300
  memory_size   = 256

  filename         = data.archive_file.dr_lambda_zip.output_path
  source_code_hash = data.archive_file.dr_lambda_zip.output_base64sha256

  environment {
    variables = {
      PRIMARY_REGION = var.primary_region
      DR_REGION      = var.dr_region
      ECS_CLUSTER    = var.ecs_cluster_name
      ECS_SERVICE    = var.ecs_service_name
      ASG_NAME       = var.asg_name
      MIN_CAPACITY   = var.min_capacity
      MAX_CAPACITY   = var.max_capacity
      DESIRED_CAPACITY = var.desired_capacity
    }
  }

  tags = var.tags
}

# Handle this with a local in Terraform for proper planning
locals {
  create_failover_resources = var.route53_health_check_id != "" ? true : false
}

resource "aws_cloudwatch_event_rule" "dr_failover_event" {
  count       = local.create_failover_resources ? 1 : 0
  name        = "${var.name_prefix}-dr-failover-event"
  description = "Captures failover events from Route 53 health checks"

  event_pattern = jsonencode({
    "source": ["aws.route53"],
    "detail-type": ["Route 53 Health Check State Change"],
    "detail": {
      "HealthCheckId": [var.route53_health_check_id],
      "State": ["ALARM"]
    }
  })
}

resource "aws_cloudwatch_event_target" "invoke_lambda_on_failover" {
  count     = local.create_failover_resources ? 1 : 0
  rule      = aws_cloudwatch_event_rule.dr_failover_event[0].name
  target_id = "DR_ScaleUp"
  arn       = aws_lambda_function.dr_scale_up.arn
}

# Monthly scheduled test rule
resource "aws_cloudwatch_event_rule" "monthly_dr_test" {
  name        = "${var.name_prefix}-monthly-dr-test"
  description = "Schedule monthly DR failover test after midnight on Sunday"
  schedule_expression = "cron(5 0 ? * MON#1 *)" # First Monday of the month at 00:05 AM
}

resource "aws_cloudwatch_event_target" "invoke_lambda_for_test" {
  rule      = aws_cloudwatch_event_rule.monthly_dr_test.name
  target_id = "DR_Test_ScaleUp"
  arn       = aws_lambda_function.dr_scale_up.arn
  
  input = jsonencode({
    "test_mode": true,
    "test_duration_minutes": 60  # Run test for 1 hour
  })
}

# Permission to allow CloudWatch Events to invoke Lambda
resource "aws_lambda_permission" "allow_cloudwatch_failover" {
  count         = local.create_failover_resources ? 1 : 0
  statement_id  = "AllowExecutionFromCloudWatchFailover"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dr_scale_up.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.dr_failover_event[0].arn
}

resource "aws_lambda_permission" "allow_cloudwatch_test" {
  statement_id  = "AllowExecutionFromCloudWatchTest"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dr_scale_up.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monthly_dr_test.arn
}

# Lambda cleanup function to restore pilot light after test
resource "aws_lambda_function" "dr_test_cleanup" {
  function_name = "${var.name_prefix}-dr-test-cleanup"
  role          = aws_iam_role.dr_lambda_role.arn
  handler       = "cleanup.handler"
  runtime       = "nodejs16.x"
  filename      = data.archive_file.dr_lambda_cleanup_zip.output_path
  source_code_hash = data.archive_file.dr_lambda_cleanup_zip.output_base64sha256
  timeout       = 300
  memory_size   = 256

  environment {
    variables = {
      DR_REGION      = var.dr_region
      ECS_CLUSTER    = var.ecs_cluster_name
      ECS_SERVICE    = var.ecs_service_name
      ASG_NAME       = var.asg_name
      PILOT_MIN_CAPACITY = var.pilot_min_capacity
      PILOT_MAX_CAPACITY = var.pilot_max_capacity
      PILOT_DESIRED_CAPACITY = var.pilot_desired_capacity
    }
  }

  tags = var.tags
}

resource "aws_iam_role" "dr_lambda_role" {
  name = "${var.name_prefix}-dr-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "dr_lambda_policy" {
  name = "${var.name_prefix}-dr-lambda-policy"
  role = aws_iam_role.dr_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:DescribeAutoScalingGroups",
          "ec2:DescribeInstances",
          "ec2:ModifyInstanceAttribute",
          "ec2:RunInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:CreateTags"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Package Lambda code
data "archive_file" "dr_lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/dr_lambda.zip"
  source {
    content  = <<-EOT
      exports.handler = async (event) => {
        const AWS = require('aws-sdk');
        
        // Testing mode
        const isTest = event.test_mode === true;
        const testDuration = event.test_duration_minutes || 60;
        
        // Set region to DR region
        AWS.config.update({region: process.env.DR_REGION});
        
        const ecs = new AWS.ECS();
        const autoscaling = new AWS.AutoScaling();
        const ec2 = new AWS.EC2();
        
        console.log('Disaster Recovery failover initiated', isTest ? "(TEST MODE)" : "");
        
        try {
          // 1. Scale up the ECS service
          console.log("Scaling up ECS service " + process.env.ECS_SERVICE + " in cluster " + process.env.ECS_CLUSTER);
          await ecs.updateService({
            cluster: process.env.ECS_CLUSTER,
            service: process.env.ECS_SERVICE,
            desiredCount: parseInt(process.env.DESIRED_CAPACITY)
          }).promise();
          
          // 2. Update the Auto Scaling Group for capacity and to use on-demand instances
          console.log("Updating ASG " + process.env.ASG_NAME + " to use on-demand instances");
          const asgParams = {
            AutoScalingGroupName: process.env.ASG_NAME,
            MinSize: parseInt(process.env.MIN_CAPACITY),
            MaxSize: parseInt(process.env.MAX_CAPACITY),
            DesiredCapacity: parseInt(process.env.DESIRED_CAPACITY),
            MixedInstancesPolicy: {
              // Switch to 100% on-demand instances during failover
              InstancesDistribution: {
                OnDemandBaseCapacity: parseInt(process.env.MIN_CAPACITY),
                OnDemandPercentageAboveBaseCapacity: 100
              }
            }
          };
          
          await autoscaling.updateAutoScalingGroup(asgParams).promise();
          
          console.log('DR environment successfully scaled up for failover');
          
          // If this is a test, schedule the cleanup after test duration
          if (isTest) {
            console.log("Test mode: Scheduling cleanup after " + testDuration + " minutes");
            
            // Create a CloudWatch Events rule to trigger cleanup after test duration
            const cloudwatchEvents = new AWS.CloudWatchEvents();
            const lambda = new AWS.Lambda();
            
            // Create a one-time rule that will trigger after test duration
            const ruleName = "dr-test-cleanup-" + Date.now();
            const scheduleExpression = "cron(" + new Date(Date.now() + testDuration * 60000).getUTCMinutes() + " " + new Date(Date.now() + testDuration * 60000).getUTCHours() + " " + new Date(Date.now() + testDuration * 60000).getUTCDate() + " " + (new Date(Date.now() + testDuration * 60000).getUTCMonth() + 1) + " ? " + new Date(Date.now() + testDuration * 60000).getUTCFullYear() + ")";
            
            await cloudwatchEvents.putRule({
              Name: ruleName,
              ScheduleExpression: scheduleExpression,
              State: 'ENABLED'
            }).promise();
            
            // Get the ARN of the cleanup Lambda function
            const lambdaParams = {
              FunctionName: process.env.AWS_LAMBDA_FUNCTION_NAME.replace('dr-scale-up', 'dr-test-cleanup')
            };
            
            const cleanupLambda = await lambda.getFunction(lambdaParams).promise();
            
            // Set the cleanup Lambda as the target for the rule
            await cloudwatchEvents.putTargets({
              Rule: ruleName,
              Targets: [
                {
                  Id: 'CleanupTarget',
                  Arn: cleanupLambda.Configuration.FunctionArn
                }
              ]
            }).promise();
            
            // Add permission for the rule to invoke the cleanup Lambda
            await lambda.addPermission({
              FunctionName: cleanupLambda.Configuration.FunctionName,
              StatementId: "AllowExecutionFromCloudWatch-" + Date.now(),
              Action: 'lambda:InvokeFunction',
              Principal: 'events.amazonaws.com',
              SourceArn: "arn:aws:events:" + process.env.DR_REGION + ":" + process.env.AWS_ACCOUNT_ID + ":rule/" + ruleName
            }).promise();
          }
          
          return {
            statusCode: 200,
            body: JSON.stringify({
              message: "DR failover completed successfully" + (isTest ? " (TEST MODE)" : ""),
              timestamp: new Date().toISOString()
            })
          };
        } catch (error) {
          console.error('Error during DR failover:', error);
          throw error;
        }
      };
    EOT
    filename = "index.js"
  }
}

data "archive_file" "dr_lambda_cleanup_zip" {
  type        = "zip"
  output_path = "${path.module}/dr_lambda_cleanup.zip"
  source {
    content  = <<-EOT
      exports.handler = async (event) => {
        const AWS = require('aws-sdk');
        
        // Set region to DR region
        AWS.config.update({region: process.env.DR_REGION});
        
        const ecs = new AWS.ECS();
        const autoscaling = new AWS.AutoScaling();
        
        console.log('DR test cleanup initiated - restoring pilot light configuration');
        
        try {
          // 1. Scale down the ECS service to pilot light levels
          console.log("Scaling down ECS service " + process.env.ECS_SERVICE + " to pilot light levels");
          await ecs.updateService({
            cluster: process.env.ECS_CLUSTER,
            service: process.env.ECS_SERVICE,
            desiredCount: parseInt(process.env.PILOT_DESIRED_CAPACITY)
          }).promise();
          
          // 2. Update the Auto Scaling Group back to pilot light configuration with spot instances
          console.log("Updating ASG " + process.env.ASG_NAME + " back to pilot light configuration");
          const asgParams = {
            AutoScalingGroupName: process.env.ASG_NAME,
            MinSize: parseInt(process.env.PILOT_MIN_CAPACITY),
            MaxSize: parseInt(process.env.PILOT_MAX_CAPACITY),
            DesiredCapacity: parseInt(process.env.PILOT_DESIRED_CAPACITY),
            MixedInstancesPolicy: {
              // Switch back to mostly spot instances for cost efficiency
              InstancesDistribution: {
                OnDemandBaseCapacity: 0,
                OnDemandPercentageAboveBaseCapacity: 0  // Use 100% spot instances for pilot light
              }
            }
          };
          
          await autoscaling.updateAutoScalingGroup(asgParams).promise();
          
          console.log('DR environment successfully restored to pilot light configuration');
          
          return {
            statusCode: 200,
            body: JSON.stringify({
              message: 'DR test cleanup completed successfully',
              timestamp: new Date().toISOString()
            })
          };
        } catch (error) {
          console.error('Error during DR test cleanup:', error);
          throw error;
        }
      };
    EOT
    filename = "cleanup.js"
  }
}