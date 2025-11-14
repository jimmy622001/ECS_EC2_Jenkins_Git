title 'RDS Database Compliance Checks'

environment = input('environment')
project = input('project')

control 'db-1' do
  impact 1.0
  title 'Ensure database is properly configured'
  desc 'Verifies that the RDS database is properly configured with appropriate settings'
  
  db_identifier = "#{project}-#{environment}-db"
  
  describe aws_rds_instance(db_instance_identifier: db_identifier) do
    it { should exist }
    its('engine') { should eq 'postgres' } # adjust based on your DB engine
    its('db_instance_status') { should eq 'available' }
    its('multi_az') { should be environment == 'prod' } # Enable MultiAZ only in prod
    
    # Check storage encryption
    it { should have_encrypted_storage }
    
    # Check for backup settings
    it 'should have backups enabled' do
      expect(subject.backup_retention_period).to be >= 7
    end
    
    # Check for proper instance type based on environment
    if environment == 'prod'
      its('db_instance_class') { should match /db\.t3\.small|db\.t3\.medium|db\.m/ }
    else
      its('db_instance_class') { should eq 'db.t3.small' }
    end
    
    # Check for appropriate tags
    it 'has proper tagging' do
      expect(subject.tags).to include('Environment' => environment)
      expect(subject.tags).to include('Project' => project)
    end
  end
end

control 'db-2' do
  impact 1.0
  title 'Ensure database is in private subnet'
  desc 'Verifies that the database is deployed in a private subnet'
  
  db_identifier = "#{project}-#{environment}-db"
  
  describe aws_rds_instance(db_instance_identifier: db_identifier) do
    it { should exist }
    
    it 'should not be publicly accessible' do
      expect(subject.publicly_accessible).to be false
    end
    
    # Check that it's in a subnet with appropriate name/tags
    it 'should be in a database subnet' do
      subnet_ids = subject.db_subnet_group.subnets.map { |s| s['subnet_identifier'] }
      subnet_ids.each do |subnet_id|
        subnet = aws_subnet(subnet_id: subnet_id)
        expect(subnet.tags).to include('Type' => 'Database')
      end
    end
  end
end

control 'db-3' do
  impact 0.8
  title 'Ensure database has proper parameter group settings'
  desc 'Verifies that database parameter groups are properly configured'
  
  db_identifier = "#{project}-#{environment}-db"
  
  describe aws_rds_instance(db_instance_identifier: db_identifier) do
    it { should exist }
    
    # Check that the instance is using a custom parameter group
    it 'should use a custom parameter group' do
      pg_name = subject.db_parameter_groups.first['db_parameter_group_name']
      expect(pg_name).to include("#{project}-#{environment}")
    end
  end
  
  # This would require checking specific parameters in the group
  # This is a simplified example
  parameter_group_name = "#{project}-#{environment}-pg"
  
  describe aws_rds_parameter_group(db_parameter_group_name: parameter_group_name) do
    it { should exist }
    its('db_parameter_group_family') { should match /postgres/ }
  end
end

control 'db-4' do
  impact 1.0
  title 'Ensure database performance insights are enabled'
  desc 'Verifies that performance insights are enabled for database monitoring'
  
  db_identifier = "#{project}-#{environment}-db"
  
  describe aws_rds_instance(db_instance_identifier: db_identifier) do
    it { should exist }
    
    # Check for performance insights
    its('performance_insights_enabled') { should be true }
    
    # Check for enhanced monitoring
    its('enhanced_monitoring_resource_arn') { should_not be_nil }
    its('monitoring_interval') { should be >= 60 }
  end
end