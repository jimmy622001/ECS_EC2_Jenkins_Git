# InSpec Compliance Profiles

This directory contains InSpec profiles for testing compliance of your AWS infrastructure against best practices and organizational standards.

## Profile Structure

There are three main profiles corresponding to each environment:

- `dev/` - Development environment compliance tests
- `prod/` - Production environment compliance tests
- `dr-pilot-light/` - Disaster Recovery environment compliance tests

Each profile contains:
- `inspec.yml` - Profile metadata and dependencies
- `controls/` - Directory containing InSpec control files grouped by component
- `files/` - Directory containing input files used during test execution (created at runtime)

## Control Files

Each profile contains specific control files that test different aspects of the infrastructure:

### Common Controls

- `vpc.rb` - Tests VPC configuration, subnets, route tables, and network ACLs
- `ecs.rb` - Tests ECS cluster, task definitions, services, and containers
- `security.rb` - Tests security groups, WAF configurations, and security services
- `database.rb` - Tests RDS database configuration, security, and performance settings

### DR-specific Controls

- `dr_readiness.rb` - Tests DR-specific configurations like replication, failover mechanisms, and documentation

## Running Locally

To run these profiles locally outside of the Jenkins pipeline:

1. Install InSpec:
```
curl https://omnitruck.chef.io/install.sh | sudo bash -s -- -P inspec
```

2. Install AWS plugin:
```
inspec plugin install inspec-aws
```

3. Configure AWS credentials:
```
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="your-region"
```

4. Run the profile:
```
inspec exec inspec-profiles/dev -t aws://eu-west-2 --input-file inspec-profiles/dev/files/inputs.yml
```

## Adding Custom Controls

To add new compliance controls:

1. Decide which component the control belongs to (vpc, ecs, security, database, etc.)
2. Add your control to the appropriate file or create a new file in the `controls/` directory
3. Follow the InSpec control format:

```ruby
control 'unique-id' do
  impact 1.0 # How important is this control (0.0 to 1.0)
  title 'Human-readable title'
  desc 'Detailed description of what this control checks'
  
  describe resource_type(resource_params) do
    it { should meet_this_condition }
    its('property') { should eq expected_value }
  end
end
```

## Understanding Results

InSpec produces results in various formats including CLI output, HTML reports, and JUnit XML for integration with Jenkins.

- **Passed**: The resource meets all specified conditions
- **Failed**: The resource doesn't meet one or more conditions
- **Skipped**: The test was skipped (usually due to conditional logic)

## References

- [InSpec Documentation](https://docs.chef.io/inspec/)
- [InSpec AWS Resource Pack](https://docs.chef.io/inspec/resources/#aws)
- [AWS Compliance Documentation](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)