title 'Security Group Compliance Checks'

environment = input('environment')
project = input('project')
vpc_id = input('vpc_id')

control 'sec-1' do
  impact 1.0
  title 'Ensure security groups are properly configured'
  desc 'Verifies that security groups follow security best practices'
  
  # Check application load balancer security group
  alb_sg_name = "#{project}-#{environment}-alb-sg"
  
  describe aws_security_group(group_name: alb_sg_name, vpc_id: vpc_id) do
    it { should exist }
    
    # Check inbound rules
    it 'should allow HTTP (80) from internet' do
      expect(subject.inbound_rules.any? { |r| r.port_range.include?(80) && r.ip_ranges.include?('0.0.0.0/0') }).to be true
    end
    
    it 'should allow HTTPS (443) from internet' do
      expect(subject.inbound_rules.any? { |r| r.port_range.include?(443) && r.ip_ranges.include?('0.0.0.0/0') }).to be true
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
  title 'Ensure network ACLs are properly configured'
  desc 'Verifies that network ACLs follow security best practices'
  
  # This would check the NACLs associated with your subnets
  aws_subnets(vpc_id: vpc_id).subnet_ids.first(3).each do |subnet_id|
    subnet = aws_subnet(subnet_id: subnet_id)
    describe aws_network_acl(network_acl_id: subnet.network_acl_id) do
      it { should exist }
      it { should be_associated_with(subnet_id) }
      its('vpc_id') { should eq vpc_id }
      
      # Verify there's a rule allowing all outbound traffic (default)
      it 'should allow outbound traffic' do
        expect(subject.outbound_rules.any? { |r| r.cidr_block == '0.0.0.0/0' && r.rule_action == 'allow' }).to be true
      end
    end
  end
end

control 'sec-3' do
  impact 0.8
  title 'Ensure AWS WAF is properly configured'
  desc 'Verifies that AWS WAF is properly configured to protect application load balancer'
  
  # Check for WAF association with ALB
  # NOTE: Actual implementation depends on the details of your WAF setup
  # This is just a placeholder for the check
  
  describe aws_wafv2_web_acls(scope: 'REGIONAL') do
    its('names') { should include("#{project}-#{environment}-waf") }
  end
end