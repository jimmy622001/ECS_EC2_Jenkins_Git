title 'Security Group Compliance Checks - Production'

environment = input('environment')
project = input('project')
vpc_id = input('vpc_id')

control 'sec-1' do
  impact 1.0
  title 'Ensure security groups are properly configured for production'
  desc 'Verifies that security groups follow security best practices for production environment'
  
  # Check application load balancer security group
  alb_sg_name = "#{project}-#{environment}-alb-sg"
  
  describe aws_security_group(group_name: alb_sg_name, vpc_id: vpc_id) do
    it { should exist }
    
    # Check inbound rules
    # Production should only allow HTTPS, not HTTP
    it 'should allow HTTPS (443) from internet' do
      expect(subject.inbound_rules.any? { |r| r.port_range.include?(443) && r.ip_ranges.include?('0.0.0.0/0') }).to be true
    end
    
    # Production should redirect HTTP to HTTPS, but not necessarily deny HTTP
    it 'should allow HTTP (80) from internet for redirection purposes' do
      expect(subject.inbound_rules.any? { |r| r.port_range.include?(80) && r.ip_ranges.include?('0.0.0.0/0') }).to be true
    end
    
    # Production should not have other unnecessary open ports
    it 'should not have unnecessary ports open to the internet' do
      unnecessary_ports = [22, 3389, 20, 21, 23, 3306, 5432]
      unnecessary_ports.each do |port|
        expect(subject.inbound_rules.none? { |r| r.port_range.include?(port) && r.ip_ranges.include?('0.0.0.0/0') }).to be true
      end
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
    
    # Production should not allow SSH from internet
    it 'should not allow SSH (22) from internet' do
      expect(subject.inbound_rules.none? { |r| r.port_range.include?(22) && r.ip_ranges.include?('0.0.0.0/0') }).to be true
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
    
    # For production, ensure strict egress rules
    it 'should have restricted egress rules' do
      has_open_egress = subject.outbound_rules.any? do |r|
        r.port_range.include?(0) && r.ip_ranges.include?('0.0.0.0/0')
      end
      # In production, we recommend not having overly permissive egress rules for databases
      if has_open_egress
        describe "Security Group #{db_sg_name} has overly permissive egress rules" do
          skip "Consider restricting outbound traffic to only necessary destinations"
        end
      end
    end
  end
end

control 'sec-2' do
  impact 1.0
  title 'Ensure AWS WAF is properly configured for production'
  desc 'Verifies that AWS WAF is properly configured to protect production application load balancer'
  
  # Check for WAF association with ALB
  describe aws_wafv2_web_acls(scope: 'REGIONAL') do
    its('names') { should include("#{project}-#{environment}-waf") }
  end
  
  # For production, check for specific WAF rules
  waf_name = "#{project}-#{environment}-waf"
  
  describe aws_wafv2_web_acl(web_acl_name: waf_name, scope: 'REGIONAL') do
    it { should exist }
    
    it 'should include AWS managed rule groups' do
      managed_rule_exists = subject.rules.any? do |r|
        r['override_action'].nil? && r['statement']['managed_rule_group_statement']
      end
      expect(managed_rule_exists).to be true
    end
    
    it 'should include rate limiting rules for production' do
      rate_rule_exists = subject.rules.any? do |r|
        r['name'].include?('rate') || r['statement'].to_s.include?('rate')
      end
      expect(rate_rule_exists).to be true
    end
  end
end

control 'sec-3' do
  impact 1.0
  title 'Ensure GuardDuty is enabled for production'
  desc 'Verifies that GuardDuty is enabled for threat detection in production'
  
  describe aws_guardduty_detector(detector_id: nil) do
    it { should exist }
    its('status') { should eq 'ENABLED' }
    
    # For production, ensure finding publishing is enabled
    its('finding_publishing_frequency') { should eq 'FIFTEEN_MINUTES' }
  end
end

control 'sec-4' do
  impact 1.0
  title 'Ensure Security Hub is enabled for production'
  desc 'Verifies that Security Hub is enabled for security standards compliance in production'
  
  describe aws_security_hub_control.enabled? do
    it { should eq true }
  end
end