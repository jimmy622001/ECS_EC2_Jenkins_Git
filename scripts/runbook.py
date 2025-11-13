#!/usr/bin/env python3
"""
Infrastructure Runbook Script for ECS AWS Environment

This script provides functionality to test, validate, and manage the ECS infrastructure
across development and production environments. It helps ensure that environments are
properly configured and running the sample application.
"""

import argparse
import json
import os
import subprocess
import sys
import time
import requests
import boto3
import datetime
import tabulate
from concurrent.futures import ThreadPoolExecutor
from botocore.exceptions import ClientError

class InfrastructureRunbook:
    def __init__(self, environment, config_path="scripts/config.json"):
        """Initialize the runbook with the specified environment."""
        self.environment = environment
        self.env_dir = os.path.join("environments", environment)
        self.app_dir = os.path.join("application", "environments", environment)

        # Load configuration
        try:
            with open(config_path, 'r') as config_file:
                self.config = json.load(config_file)
        except FileNotFoundError:
            print(f"Configuration file not found: {config_path}")
            self.config = self._create_default_config()
            with open(config_path, 'w') as config_file:
                json.dump(self.config, config_file, indent=2)
            print(f"Created default configuration file: {config_path}")

        # Initialize AWS session if credentials are available
        try:
            self.session = boto3.Session(profile_name=self.config.get("aws_profile", None))
            self.ec2 = self.session.client('ec2')
            self.ecs = self.session.client('ecs')
            self.elb = self.session.client('elbv2')
            self.logs = self.session.client('logs')
            self.elasticache = self.session.client('elasticache')
            self.has_aws_creds = True
        except Exception as e:
            print(f"Warning: Could not initialize AWS session: {e}")
            print("Some features will be limited without AWS credentials")
            self.has_aws_creds = False

    def _create_default_config(self):
        """Create a default configuration if none exists."""
        return {
            "aws_profile": "default",
            "regions": {
                "dev": "us-east-1",
                "prod": "us-east-1"
            },
            "health_check_paths": {
                "dev": "/health",
                "prod": "/health"
            },
            "expected_services": {
                "dev": ["ecs", "elasticache", "alb"],
                "prod": ["ecs", "elasticache", "alb"]
            },
            "load_test": {
                "concurrent_users": 10,
                "duration_seconds": 30,
                "requests_per_second": 5
            },
            "report_output_dir": "runbook_reports"
        }

    def validate_environment(self):
        """Validate that the environment directory and configuration exist."""
        issues = []

        # Check environment directory
        if not os.path.isdir(self.env_dir):
            issues.append(f"Environment directory '{self.env_dir}' not found")

        # Check required files
        required_files = {
            f"{self.env_dir}/main.tf": "Main Terraform configuration",
            f"{self.env_dir}/terraform.tfvars": "Terraform variables",
            f"{self.env_dir}/variables.tf": "Terraform variables definitions",
            f"{self.app_dir}/main.tf": "Application Terraform configuration",
        }

        for file_path, description in required_files.items():
            if not os.path.isfile(file_path):
                issues.append(f"Required {description} file not found: {file_path}")

        # Validate terraform.tfvars content
        if os.path.isfile(f"{self.env_dir}/terraform.tfvars"):
            try:
                with open(f"{self.env_dir}/terraform.tfvars", 'r') as f:
                    content = f.read()
                    if not "container_image" in content:
                        issues.append("No container image specified in terraform.tfvars")
                    if not "container_port" in content:
                        issues.append("No container port specified in terraform.tfvars")
            except Exception as e:
                issues.append(f"Could not read terraform.tfvars: {e}")

        if issues:
            print("Environment validation failed:")
            for issue in issues:
                print(f"  - {issue}")
            return False

        print(f"Environment '{self.environment}' validated successfully.")
        return True

    def get_terraform_outputs(self):
        """Get the Terraform outputs for the environment."""
        if not os.path.isdir(self.env_dir):
            print(f"Environment directory '{self.env_dir}' not found")
            return None

        try:
            result = subprocess.run(
                ["terraform", "output", "-json"],
                cwd=self.env_dir,
                capture_output=True,
                text=True,
                check=True
            )
            return json.loads(result.stdout)
        except subprocess.CalledProcessError as e:
            print(f"Failed to get Terraform outputs: {e.stderr}")
            return None
        except json.JSONDecodeError as e:
            print(f"Failed to parse Terraform outputs: {e}")
            return None

    def test_app_health(self):
        """Test the health of the application."""
        outputs = self.get_terraform_outputs()
        if not outputs:
            print("Could not get infrastructure outputs")
            return False

        # Get the ALB DNS name from outputs
        alb_dns = None
        for key in outputs:
            if "alb" in key.lower() and "dns" in key.lower():
                alb_dns = outputs[key]["value"]
                break

        if not alb_dns:
            print("Could not find ALB DNS name in Terraform outputs")
            return False

        # Determine health check path
        health_path = self.config.get("health_check_paths", {}).get(self.environment, "/health")

        # Test HTTP connection
        url = f"http://{alb_dns}_{health_path}"
        print(f"Testing application health at: {url}")

        max_attempts = 3
        attempt = 0

        while attempt < max_attempts:
            try:
                response = requests.get(url, timeout=10)
                if response.status_code == 200:
                    print(f"Health check successful: HTTP {response.status_code}")
                    print(f"Response body: {response.text[:200]}")
                    return True
                else:
                    print(f"Health check failed: HTTP {response.status_code}")
                    print(f"Response body: {response.text[:200]}")
            except requests.exceptions.RequestException as e:
                print(f"Health check attempt {attempt+1} failed: {e}")

            attempt += 1
            if attempt < max_attempts:
                wait_time = 5 * attempt
                print(f"Waiting {wait_time} seconds before retry...")
                time.sleep(wait_time)

        return False

    def get_aws_resources(self):
        """Get AWS resources for the environment."""
        if not self.has_aws_creds:
            print("AWS credentials not available")
            return {}

        resources = {}

        try:
            # Get ECS clusters
            clusters = self.ecs.list_clusters()
            resources["ecs_clusters"] = clusters["clusterArns"]

            # Get load balancers
            load_balancers = self.elb.describe_load_balancers()
            resources["load_balancers"] = [lb["LoadBalancerArn"] for lb in load_balancers["LoadBalancers"]]

            # Get ElastiCache clusters
            cache_clusters = self.elasticache.describe_cache_clusters()
            resources["cache_clusters"] = [cluster["CacheClusterId"] for cluster in cache_clusters["CacheClusters"]]

            # Get EC2 instances
            instances = self.ec2.describe_instances()
            resources["ec2_instances"] = []
            for reservation in instances["Reservations"]:
                for instance in reservation["Instances"]:
                    resources["ec2_instances"].append({
                        "id": instance["InstanceId"],
                        "state": instance["State"]["Name"],
                        "type": instance.get("InstanceType", "unknown")
                    })

        except Exception as e:
            print(f"Error getting AWS resources: {e}")

        return resources

    def check_security_groups(self):
        """Check security group rules for issues."""
        if not self.has_aws_creds:
            print("AWS credentials not available")
            return []

        issues = []

        try:
            # Get all security groups
            security_groups = self.ec2.describe_security_groups()

            for sg in security_groups["SecurityGroups"]:
                sg_id = sg["GroupId"]
                sg_name = sg["GroupName"]

                # Check for overly permissive rules
                for rule in sg["IpPermissions"]:
                    for ip_range in rule.get("IpRanges", []):
                        cidr = ip_range.get("CidrIp", "")
                        if cidr == "0.0.0.0/0":
                            protocol = rule.get("IpProtocol", "all")
                            from_port = rule.get("FromPort", "all")
                            to_port = rule.get("ToPort", "all")

                            # Check if this is HTTP/HTTPS, which might be acceptable
                            if not (protocol == "tcp" and ((from_port == 80 and to_port == 80) or
                                                            (from_port == 443 and to_port == 443))):
                                issues.append(f"Security group {sg_id} ({sg_name}) has overly permissive rule: "
                                             f"{protocol} {from_port}-{to_port} from {cidr}")

        except Exception as e:
            issues.append(f"Error checking security groups: {e}")

        return issues

    def check_cloudwatch_logs(self):
        """Check CloudWatch logs for errors."""
        if not self.has_aws_creds:
            print("AWS credentials not available")
            return []

        log_issues = []

        try:
            # List log groups
            response = self.logs.describe_log_groups()
            log_groups = [group["logGroupName"] for group in response["logGroups"]]

            # Look for ECS and application related log groups
            ecs_log_groups = [lg for lg in log_groups if "ecs" in lg.lower()]

            for log_group in ecs_log_groups:
                # Get log streams
                streams = self.logs.describe_log_streams(
                    logGroupName=log_group,
                    orderBy="LastEventTime",
                    descending=True,
                    limit=5
                )

                # Check the most recent stream
                if streams["logStreams"]:
                    recent_stream = streams["logStreams"][0]

                    # Get recent logs
                    logs = self.logs.get_log_events(
                        logGroupName=log_group,
                        logStreamName=recent_stream["logStreamName"],
                        limit=100,
                        startFromHead=False
                    )

                    # Look for error messages
                    error_count = 0
                    for event in logs["events"]:
                        message = event["message"].lower()
                        if "error" in message or "exception" in message or "fail" in message:
                            error_count += 1
                            if error_count <= 5:  # Limit the number of errors we report
                                timestamp = datetime.datetime.fromtimestamp(event["timestamp"]/1000)
                                log_issues.append(f"Error in {log_group} at {timestamp}: {event['message'][:100]}...")

                    if error_count > 5:
                        log_issues.append(f"Found {error_count} total errors in {log_group}")

        except Exception as e:
            log_issues.append(f"Error checking CloudWatch logs: {e}")

        return log_issues

    def run_load_test(self):
        """Run a simple load test against the application."""
        outputs = self.get_terraform_outputs()
        if not outputs:
            print("Could not get infrastructure outputs")
            return False

        # Get the ALB DNS name from outputs
        alb_dns = None
        for key in outputs:
            if "alb" in key.lower() and "dns" in key.lower():
                alb_dns = outputs[key]["value"]
                break

        if not alb_dns:
            print("Could not find ALB DNS name in Terraform outputs")
            return False

        url = f"http://{alb_dns}/"

        # Get load test configuration
        config = self.config.get("load_test", {})
        concurrent_users = config.get("concurrent_users", 10)
        duration_seconds = config.get("duration_seconds", 30)
        requests_per_second = config.get("requests_per_second", 5)

        print(f"Running load test against {url}")
        print(f"- Concurrent users: {concurrent_users}")
        print(f"- Duration: {duration_seconds} seconds")
        print(f"- Target RPS: {requests_per_second}")

        results = {
            "total_requests": 0,
            "successful_requests": 0,
            "failed_requests": 0,
            "response_times": [],
            "errors": []
        }

        def make_request():
            start_time = time.time()
            try:
                response = requests.get(url, timeout=5)
                elapsed = time.time() - start_time
                return {
                    "success": response.status_code == 200,
                    "status_code": response.status_code,
                    "elapsed": elapsed
                }
            except Exception as e:
                elapsed = time.time() - start_time
                return {
                    "success": False,
                    "status_code": 0,
                    "error": str(e),
                    "elapsed": elapsed
                }

        start_time = time.time()
        end_time = start_time + duration_seconds

        with ThreadPoolExecutor(max_workers=concurrent_users) as executor:
            futures = []

            while time.time() < end_time:
                # Submit new requests based on desired rate
                for _ in range(requests_per_second):
                    futures.append(executor.submit(make_request))

                # Sleep to control request rate
                time.sleep(1)

            # Wait for all futures to complete
            for future in futures:
                result = future.result()
                results["total_requests"] += 1

                if result["success"]:
                    results["successful_requests"] += 1
                else:
                    results["failed_requests"] += 1
                    if "error" in result:
                        results["errors"].append(result["error"])
                    else:
                        results["errors"].append(f"Status code: {result['status_code']}")

                results["response_times"].append(result["elapsed"])

        # Calculate statistics
        if results["response_times"]:
            results["avg_response_time"] = sum(results["response_times"]) / len(results["response_times"])
            results["max_response_time"] = max(results["response_times"])
            results["min_response_time"] = min(results["response_times"])
        else:
            results["avg_response_time"] = 0
            results["max_response_time"] = 0
            results["min_response_time"] = 0

        # Print results
        print("\nLoad Test Results:")
        print(f"Total Requests: {results['total_requests']}")
        print(f"Successful Requests: {results['successful_requests']} ({results['successful_requests']/results['total_requests']*100 if results['total_requests'] > 0 else 0:.2f}%)")
        print(f"Failed Requests: {results['failed_requests']}")
        print(f"Average Response Time: {results['avg_response_time']:.4f} seconds")
        print(f"Min Response Time: {results['min_response_time']:.4f} seconds")
        print(f"Max Response Time: {results['max_response_time']:.4f} seconds")

        if results["errors"]:
            print("\nSample Errors:")
            for i, error in enumerate(results["errors"][:5]):
                print(f"  {i+1}. {error}")
            if len(results["errors"]) > 5:
                print(f"  ... and {len(results['errors']) - 5} more errors")

        # Check if test passed
        success_rate = results['successful_requests']/results['total_requests'] if results['total_requests'] > 0 else 0
        passed = success_rate >= 0.9  # At least 90% success rate is considered passing

        print(f"\nLoad Test {'PASSED' if passed else 'FAILED'}")
        return passed

    def compare_environments(self, other_env):
        """Compare this environment with another environment."""
        other_runbook = InfrastructureRunbook(other_env)

        print(f"Comparing {self.environment} with {other_env}")

        # Get outputs for both environments
        self_outputs = self.get_terraform_outputs()
        other_outputs = other_runbook.get_terraform_outputs()

        if not self_outputs or not other_outputs:
            print("Could not get outputs for one or both environments")
            return

        # Compare outputs
        print("\nComparison of infrastructure outputs:")

        # Find all unique keys
        all_keys = set(self_outputs.keys()) | set(other_outputs.keys())

        # Create comparison table
        table = []
        for key in sorted(all_keys):
            self_value = self_outputs.get(key, {}).get("value", "N/A")
            other_value = other_outputs.get(key, {}).get("value", "N/A")

            # Format values for display
            if isinstance(self_value, (dict, list)):
                self_value = json.dumps(self_value)[:50] + "..." if len(json.dumps(self_value)) > 50 else json.dumps(self_value)
            if isinstance(other_value, (dict, list)):
                other_value = json.dumps(other_value)[:50] + "..." if len(json.dumps(other_value)) > 50 else json.dumps(other_value)

            match = "✓" if self_value == other_value else "✗"
            table.append([key, str(self_value)[:50], str(other_value)[:50], match])

        print(tabulate.tabulate(table,
                               headers=[f"Output", f"{self.environment}", f"{other_env}", "Match"],
                               tablefmt="grid"))

        # Compare tfvars files
        print("\nComparison of terraform.tfvars:")
        try:
            with open(f"{self.env_dir}/terraform.tfvars", 'r') as f:
                self_tfvars = f.readlines()

            with open(f"environments/{other_env}/terraform.tfvars", 'r') as f:
                other_tfvars = f.readlines()

            # Create simple diff
            diff_table = []
            for line in self_tfvars:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue

                # Extract variable name and value
                parts = line.split("=", 1)
                if len(parts) == 2:
                    var_name = parts[0].strip()
                    var_value = parts[1].strip()

                    # Find matching line in other env
                    other_value = "Not set"
                    for other_line in other_tfvars:
                        other_line = other_line.strip()
                        if other_line.startswith(var_name + " =") or other_line.startswith(var_name + "="):
                            other_parts = other_line.split("=", 1)
                            if len(other_parts) == 2:
                                other_value = other_parts[1].strip()
                                break

                    match = "✓" if var_value == other_value else "✗"
                    diff_table.append([var_name, var_value[:50], other_value[:50], match])

            print(tabulate.tabulate(diff_table,
                                  headers=[f"Variable", f"{self.environment}", f"{other_env}", "Match"],
                                  tablefmt="grid"))

        except Exception as e:
            print(f"Error comparing tfvars files: {e}")

    def create_report(self):
        """Create a comprehensive HTML report for the environment."""
        outputs = self.get_terraform_outputs()
        if not outputs:
            print("Could not get infrastructure outputs")
            return False

        # Create report directory
        report_dir = self.config.get("report_output_dir", "runbook_reports")
        if not os.path.exists(report_dir):
            os.makedirs(report_dir)

        # Create timestamped report file
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = os.path.join(report_dir, f"{self.environment}_report_{timestamp}.html")

        # Test application health
        health_status = self.test_app_health()

        # Get AWS resources if credentials available
        resources = self.get_aws_resources() if self.has_aws_creds else {}

        # Check security groups
        sg_issues = self.check_security_groups() if self.has_aws_creds else []

        # Check CloudWatch logs
        log_issues = self.check_cloudwatch_logs() if self.has_aws_creds else []

        # Create HTML report
        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>{self.environment.upper()} Environment Report</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; }}
                h1 {{ color: #333; }}
                h2 {{ color: #444; margin-top: 30px; }}
                table {{ border-collapse: collapse; width: 100%; margin-top: 10px; }}
                th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
                th {{ background-color: #f2f2f2; }}
                tr:nth-child(even) {{ background-color: #f9f9f9; }}
                .status-ok {{ color: green; }}
                .status-warning {{ color: orange; }}
                .status-error {{ color: red; }}
                .summary {{ background-color: #f0f0f0; padding: 15px; border-radius: 5px; margin-top: 20px; }}
            </style>
        </head>
        <body>
            <h1>{self.environment.upper()} Environment Report</h1>
            <p>Generated on {datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}</p>
            
            <div class="summary">
                <h2>Summary</h2>
                <p>Health Check: <span class="status-{'ok' if health_status else 'error'}">{
                    "PASSED" if health_status else "FAILED"}</span></p>
                <p>Security Issues: <span class="status-{'error' if sg_issues else 'ok'}">{
                    len(sg_issues)} found</span></p>
                <p>Log Issues: <span class="status-{'warning' if log_issues else 'ok'}">{
                    len(log_issues)} found</span></p>
            </div>
            
            <h2>Infrastructure Outputs</h2>
            <table>
                <tr><th>Output</th><th>Value</th></tr>
        """

        # Add outputs to report
        for key, output in outputs.items():
            value = output.get("value", "N/A")
            if isinstance(value, (dict, list)):
                value = json.dumps(value, indent=2)
            html += f"<tr><td>{key}</td><td><pre>{value}</pre></td></tr>\n"

        html += """
            </table>
            
            <h2>Application Health</h2>
        """

        if health_status:
            html += """
            <p class="status-ok">The application health check passed. The application is responding as expected.</p>
            """
        else:
            html += """
            <p class="status-error">The application health check failed. The application is not responding correctly.</p>
            """

        # Add AWS resources if available
        if resources:
            html += """
            <h2>AWS Resources</h2>
            """

            for resource_type, resource_list in resources.items():
                html += f"<h3>{resource_type}</h3>\n<ul>\n"

                if isinstance(resource_list, list):
                    for resource in resource_list:
                        if isinstance(resource, dict):
                            # For EC2 instances with detailed info
                            resource_str = ", ".join([f"{k}: {v}" for k, v in resource.items()])
                            html += f"<li>{resource_str}</li>\n"
                        else:
                            html += f"<li>{resource}</li>\n"

                html += "</ul>\n"

        # Add security group issues if any
        if sg_issues:
            html += """
            <h2>Security Group Issues</h2>
            <table>
                <tr><th>Issue</th></tr>
            """

            for issue in sg_issues:
                html += f"<tr><td>{issue}</td></tr>\n"

            html += "</table>\n"

        # Add log issues if any
        if log_issues:
            html += """
            <h2>CloudWatch Log Issues</h2>
            <table>
                <tr><th>Issue</th></tr>
            """

            for issue in log_issues:
                html += f"<tr><td>{issue}</td></tr>\n"

            html += "</table>\n"

        html += """
        </body>
        </html>
        """

        # Write report to file
        with open(report_file, 'w') as f:
            f.write(html)

        print(f"Report generated: {report_file}")
        return report_file

def main():
    """Main entry point for the runbook script."""
    parser = argparse.ArgumentParser(description="Infrastructure Runbook for ECS AWS Environment")
    parser.add_argument("action", choices=["test", "validate", "health-check", "resources",
                                           "security", "logs", "load-test", "compare", "report"],
                        help="Action to perform")
    parser.add_argument("environment", choices=["dev", "prod"],
                        help="Environment to target")
    parser.add_argument("--compare-with", choices=["dev", "prod"],
                        help="Second environment for comparison (use with compare action)")
    parser.add_argument("--config", default="scripts/config.json",
                        help="Path to configuration file")

    args = parser.parse_args()

    # Create runbook instance
    runbook = InfrastructureRunbook(args.environment, args.config)

    # Execute requested action
    if args.action == "validate":
        runbook.validate_environment()

    elif args.action == "test":
        if runbook.validate_environment():
            print("Environment validation passed")
            if runbook.test_app_health():
                print("Application health check passed")
                result = True
            else:
                print("Application health check failed")
                result = False
        else:
            print("Environment validation failed")
            result = False

        sys.exit(0 if result else 1)

    elif args.action == "health-check":
        result = runbook.test_app_health()
        sys.exit(0 if result else 1)

    elif args.action == "resources":
        resources = runbook.get_aws_resources()
        print(json.dumps(resources, indent=2))

    elif args.action == "security":
        issues = runbook.check_security_groups()
        if issues:
            print("Security issues found:")
            for issue in issues:
                print(f"- {issue}")
            sys.exit(1)
        else:
            print("No security issues found!")
            sys.exit(0)

    elif args.action == "logs":
        issues = runbook.check_cloudwatch_logs()
        if issues:
            print("Log issues found:")
            for issue in issues:
                print(f"- {issue}")
            sys.exit(1)
        else:
            print("No log issues found!")
            sys.exit(0)

    elif args.action == "load-test":
        result = runbook.run_load_test()
        sys.exit(0 if result else 1)

    elif args.action == "compare":
        if not args.compare_with:
            print("Error: --compare-with argument is required for compare action")
            sys.exit(1)
        if args.environment == args.compare_with:
            print("Error: Cannot compare an environment with itself")
            sys.exit(1)
        runbook.compare_environments(args.compare_with)

    elif args.action == "report":
        report_file = runbook.create_report()
        if report_file:
            print(f"Report generated: {report_file}")
            sys.exit(0)
        else:
            print("Failed to generate report")
            sys.exit(1)

if __name__ == "__main__":
    main()