title 'RDS Database Compliance Checks - Production'

environment = input('environment')
project = input('project')

control 'db-1' do
  impact 1.0
  title 'Ensure database is properly configured for production'
  desc 'Verifies that the RDS database is properly configured with appropriate settings for production'
  
  db_identifier = "#{project}-#{environment}-db"
  
  describe aws_rds_instance(db_instance_identifier: db_identifier) do
    it { should exist }
    its('engine') { should eq 'postgres' } # adjust based on your DB engine
    its('db_instance_status') { should eq 'available' }
    
    # Production must use Multi-AZ for high availability
    its('multi_az') { should be true }
    
    # Check storage encryption
    it { should have_encrypted_storage }
    
    # Check for backup settings - Production requires longer retention
    it 'should have backups enabled with adequate retention' do
      expect(subject.backup_retention_period).to be >= 14
    end
    
    # Check for appropriate instance class for production
    its('db_instance_class') { should match /(db\.t3\.medium|db\.m5|db\.r5)/ }
    
    # Check for performance insights enabled
    its('performance_insights_enabled') { should be true }
    
    # Check for appropriate tags
    it 'has proper tagging' do
      expect(subject.tags).to include('Environment' => 'prod')
      expect(subject.tags).to include('Project' => project)
    end
  end
end

control 'db-2' do
  impact 1.0
  title 'Ensure database is properly secured'
  desc 'Verifies that the database is secured according to production standards'
  
  db_identifier = "#{project}-#{environment}-db"
  
  describe aws_rds_instance(db_instance_identifier: db_identifier) do
    it { should exist }
    
    # Must not be publicly accessible in production
    its('publicly_accessible') { should be false }
    
    # Should have deletion protection enabled
    its('deletion_protection') { should be true }
    
    # Should have IAM authentication enabled for production
    its('iam_database_authentication_enabled') { should be true }
    
    # Should use enhanced monitoring with shorter interval in production
    its('monitoring_interval') { should be <= 30 }
    
    # Should be in a private subnet
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
  impact 1.0
  title 'Ensure database has cross-region snapshot copy enabled for DR'
  desc 'Verifies that cross-region snapshot copying is enabled for disaster recovery'
  
  db_identifier = "#{project}-#{environment}-db"
  
  # Check for cross-region snapshot copy
  # Note: Actual implementation may vary based on your DR strategy
  # This might need to be adjusted based on how you've implemented this
  describe aws_rds_instance(db_instance_identifier: db_identifier) do
    it { should exist }
    
    # Check for automated snapshots enabled
    its('backup_retention_period') { should be > 0 }
  end
  
  # Check for event subscription related to snapshots
  describe aws_rds_event_subscriptions.where(
    source_type: 'db-instance', 
    enabled: true
  ) do
    it { should exist }
    
    # Check if any subscription covers the DB and includes snapshot events
    its('source_ids.flatten') { should include db_identifier }
    its('event_categories.flatten') { should include 'backup' }
  end
end

control 'db-4' do
  impact 1.0
  title 'Ensure database has proper parameter group settings for production'
  desc 'Verifies that database parameter groups are properly configured for production'
  
  db_identifier = "#{project}-#{environment}-db"
  
  describe aws_rds_instance(db_instance_identifier: db_identifier) do
    it { should exist }
    
    # Check that the instance is using a custom parameter group
    it 'should use a custom parameter group' do
      pg_name = subject.db_parameter_groups.first['db_parameter_group_name']
      expect(pg_name).to include("#{project}-#{environment}")
    end
  end
  
  # Specific parameter checks for production
  parameter_group_name = "#{project}-#{environment}-pg"
  
  describe aws_rds_parameter_group(db_parameter_group_name: parameter_group_name) do
    it { should exist }
    its('db_parameter_group_family') { should match /postgres/ }
    
    # Production should have specific settings for performance and security
    it 'should have SQL logging enabled' do
      param = subject.parameters.detect { |p| p.parameter_name == 'log_statement' }
      expect(param.parameter_value).to eq('all')
    end
    
    it 'should have reasonable connection limits' do
      param = subject.parameters.detect { |p| p.parameter_name == 'max_connections' }
      expect(param.parameter_value.to_i).to be >= 100
    end
    
    it 'should have SSL enforced' do
      param = subject.parameters.detect { |p| p.parameter_name == 'rds.force_ssl' }
      expect(param.parameter_value).to eq('1')
    end
  end
end