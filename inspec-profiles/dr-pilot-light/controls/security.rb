title 'Security Group Compliance Checks - DR Environment'

environment = input('environment')
project = input('project')
vpc_id = input('vpc_id')

control 'sec-1' do
  impact 1.0
  title 'Ensure security groups are properly configured in DR environment'
  desc 'Verifies that security groups follow security best practices in DR environment'
  
  # Check application load balancer security group
  alb_sg_name = "#{project}-#{environment}-alb-sg"
  
  describe aws_security_group(group_name: alb_sg_name, vpc_id: vpc_id) do
    it { should exist }
    
    # Check inbound rules
    # DR environment should match production security posture
    it 'should allow HTTPS (443) from internet' do
      expect(subject.inbound_rules.any? { |r| r.port_range.include?(443) && r.ip_ranges.include?('0.0.0.0/0') }).to be true
    end
    
    # DR should have HTTP for redirection, but not direct access
    it 'should allow HTTP (80) from internet for redirection purposes only' do
      expect(subject.inbound_rules.any? { |r| r.port_range.include?(80) && r.ip_ranges.include?('0.0.0.0/0') }).to be true
    end
    
    # Check outbound rules (should allow all outbound)
    it 'should allow all outbound traffic' do
      expect(subject.outbound_rules.any? { |r| r.port_range.include?(0) && r.ip_ranges.include?('0.0.0.0/0') }).to be true
    end
  end
  
  # Check ECS security group
  ecs_sg_name = "#{project}-#{environment}-ecs-sg"
  
  describe aws_security_group(group_name: ecs_sg_name, vpc_id: vpc_id) do
    it { should exist }
    
    # ECS SG should only accept traffic from ALB SG
    it 'should allow inbound only from ALB security group' do
      inbound_from_other_than_alb = subject.inbound_rules.any? do |r| 
        !r.security_groups.include?(alb_sg_name) && !r.ip_ranges.empty?
      end
      expect(inbound_from_other_than_alb).to be false
    end
    
    # Check outbound rules (should allow all outbound)
    it 'should allow all outbound traffic' do
      expect(subject.outbound_rules.any? { |r| r.port_range.include?(0) && r.ip_ranges.include?('0.0.0.0/0') }).to be true
    end
  end
  
  # Check DB security group
  db_sg_name = "#{project}-#{environment}-db-sg"
  
  describe aws_security_group(group_name: db_sg_name, vpc_id: vpc_id) do
    it { should exist }
    
    # DB SG should only accept traffic from ECS SG on proper port
    it 'should allow inbound only from ECS security group on DB port' do
      has_proper_rule = subject.inbound_rules.any? do |r|
        r.port_range.include?(5432) && r.security_groups.include?(ecs_sg_name)
      end
      expect(has_proper_rule).to be true
    end
    
    # Should not allow direct internet access
    it 'should not allow inbound from internet' do
      has_internet_rule = subject.inbound_rules.any? do |r|
        r.ip_ranges.include?('0.0.0.0/0')
      end
      expect(has_internet_rule).to be false
    end
  end
end

control 'sec-2' do
  impact 1.0
  title 'Ensure AWS security services are enabled in DR region'
  desc 'Verifies that security services like GuardDuty and Security Hub are enabled in DR region'
  
  # Check GuardDuty
  describe aws_guardduty_detector(detector_id: nil) do
    it { should exist }
    its('status') { should eq 'ENABLED' }
  end
  
  # Check Security Hub
  describe aws_security_hub_control.enabled? do
    it { should eq true }
  end
  
  # Check Config
  describe aws_config_recorder do
    it { should exist }
    it { should be_recording }
    its('recording_group.include_global_resource_types') { should be true }
  end
end

control 'sec-3' do
  impact 1.0
  title 'Ensure data encryption is enabled in DR environment'
  desc 'Verifies that encryption is enabled for data at rest and in transit in DR environment'
  
  # Check for S3 bucket encryption
  # Identify buckets in your DR environment
  aws_s3_buckets.bucket_names.each do |bucket_name|
    if bucket_name.include?("#{project}") && bucket_name.include?("#{environment}")
      describe aws_s3_bucket(bucket_name: bucket_name) do
        it { should exist }
        it { should have_default_encryption_enabled }
      end
    end
  end
  
  # Check for RDS encryption
  db_identifier = "#{project}-#{environment}-db"
  
  describe aws_rds_instance(db_instance_identifier: db_identifier) do
    it { should exist }
    it { should have_encrypted_storage }
  end
  
  # Check for EBS encryption by default
  describe aws_ebs_encryption_by_default do
    it { should be_encrypted_by_default }
  end
end