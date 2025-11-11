# IAM Module - Outputs

output "ecs_task_execution_role" {
  description = "ARN of ECS task execution role"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role" {
  description = "ARN of ECS task role"
  value       = aws_iam_role.ecs_task_role.arn
}

output "jenkins_role" {
  description = "ARN of Jenkins role"
  value       = aws_iam_role.jenkins_role.arn
}

output "jenkins_instance_profile" {
  description = "Name of Jenkins instance profile"
  value       = aws_iam_instance_profile.jenkins.name
}

output "codedeploy_role" {
  description = "ARN of CodeDeploy role"
  value       = aws_iam_role.codedeploy_role.arn
}