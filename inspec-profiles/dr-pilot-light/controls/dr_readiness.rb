title 'Disaster Recovery Readiness Checks'

environment = input('environment')
project = input('project')
vpc_id = input('vpc_id')

control 'dr-1' do
  impact 1.0
  title 'Ensure DR environment has essential infrastructure components'
  desc 'Verifies that the DR environment has all necessary components for failover'
  
  # Check if ECS cluster exists in DR region
  cluster_name = "#{project}-#{environment}-cluster"
  
  describe aws_ecs_cluster(cluster_name: cluster_name) do
    it { should exist }
    its('status') { should eq 'ACTIVE' }
  end
  
  # Check if essential networking components exist
  describe aws_vpcs.where(vpc_id: vpc_id) do
    it { should exist }
  end
  
  # Check if ECR repository exists and is accessible in DR region
  # Note: This is just a placeholder - actual implementation depends on ECR setup
  describe aws_ecr_repository(repository_name: "#{project}-dr") do
    it { should exist }
  end
end

control 'dr-2' do
  impact 1.0
  title 'Ensure cross-region database replication is set up'
  desc 'Verifies that database replication or snapshot copying is set up for DR'
  
  # Check for RDS read replica or Aurora global database
  # This is a simplified check - adjust based on your specific DB replication strategy
  db_identifier = "#{project}-#{environment}-db"
  
  describe aws_rds_instance(db_instance_identifier: db_identifier) do
    it { should exist }
    
    # If using read replicas for DR
    it 'should be configured as part of a DR strategy' do
      is_read_replica = !subject.read_replica_source_db_instance_identifier.nil?
      is_primary = !subject.read_replica_db_instance_identifiers.empty?
      
      expect(is_read_replica || is_primary).to be true
    end
  end
end

control 'dr-3' do
  impact 1.0
  title 'Ensure DR environment has backup recovery mechanisms'
  desc 'Verifies that backup and recovery mechanisms are in place for DR'
  
  # Check if AWS Backup vault exists in DR region
  describe aws_backup_vaults do
    its('names') { should include /#{project}-#{environment}/ }
  end
  
  # Check for backup plans that include cross-region copy
  describe aws_backup_plans do
    it { should exist }
    
    # Check if any plan includes cross-region copy
    # Note: Actual implementation depends on how backups are set up
    it 'should have plans with cross-region copy' do
      has_cross_region_plan = subject.any? do |plan|
        plan.backup_plan.rules.any? do |rule|
          !rule.copy_actions.nil? && !rule.copy_actions.empty?
        end
      end
      expect(has_cross_region_plan).to be true
    end
  end
end

control 'dr-4' do
  impact 1.0
  title 'Ensure DR failover mechanisms are properly configured'
  desc 'Verifies that DR failover mechanisms like Route 53 health checks are properly configured'
  
  # Check for Route 53 health checks related to primary region endpoints
  describe aws_route53_health_checks do
    it { should exist }
    # Check for health checks targeting the primary region endpoints
    its('count') { should be > 0 }
  end
  
  # Check for Route 53 failover record sets
  describe aws_route53_hosted_zones do
    it { should exist }
    
    it 'should have failover record sets configured' do
      has_failover_records = subject.any? do |zone|
        aws_route53_record_sets(hosted_zone_id: zone.id).any? do |record_set|
          !record_set.failover.nil?
        end
      end
      expect(has_failover_records).to be true
    end
  end
end

control 'dr-5' do
  impact 1.0
  title 'Ensure DR processes and procedures are documented'
  desc 'Verifies that DR processes are documented and accessible'
  
  # Check for the existence of DR documentation in S3
  # This is a simplified check - adjust based on how you store DR documentation
  describe aws_s3_bucket(bucket_name: "#{project}-documentation") do
    it { should exist }
    
    it 'should contain DR documentation' do
      has_dr_docs = aws_s3_bucket_objects(bucket_name: "#{project}-documentation").any? do |object|
        object.key.include?('dr') || object.key.include?('disaster-recovery')
      end
      expect(has_dr_docs).to be true
    end
  end
end