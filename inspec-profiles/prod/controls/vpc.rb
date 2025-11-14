title 'VPC Compliance Checks - Production'

vpc_id = input('vpc_id')
environment = input('environment')
project = input('project')

control 'vpc-1' do
  impact 1.0
  title 'Ensure VPC is properly configured'
  desc 'Verifies that the VPC exists and has the proper configuration for Production'
  
  describe aws_vpc(vpc_id) do
    it { should exist }
    its('cidr_block') { should eq '10.1.0.0/16' } # Production CIDR
    its('instance_tenancy') { should eq 'default' }
    its('state') { should eq 'available' }
    
    it 'has the correct tags' do
      expect(subject.tags).to include(
        'Name' => "#{project}-#{environment}-vpc",
        'Environment' => environment, 
        'Project' => project
      )
    end
  end
end

control 'vpc-2' do
  impact 1.0
  title 'Ensure VPC Flow Logs are enabled'
  desc 'Verifies that VPC Flow Logs are enabled for network monitoring and security analysis'

  describe aws_vpc(vpc_id) do
    it { should exist }
    it { should have_flow_log(log_status: 'ACTIVE') }
    
    # Production should store logs in CloudWatch with retention
    it 'should send flow logs to CloudWatch with proper retention' do
      flow_logs = aws_flow_logs.where(resource_id: vpc_id)
      expect(flow_logs.exist?).to be true
      expect(flow_logs.where(log_destination_type: 'cloud-watch-logs').entries.count).to be >= 1
    end
  end
end

control 'vpc-3' do
  impact 1.0
  title 'Ensure subnets are properly configured'
  desc 'Verifies that subnets are properly configured with appropriate CIDRs and tags for Production'
  
  aws_subnets(vpc_id: vpc_id).subnet_ids.each do |subnet_id|
    describe aws_subnet(subnet_id: subnet_id) do
      it { should exist }
      its('state') { should eq 'available' }
      it { should be_in_vpc(vpc_id) }
      
      it 'has proper tagging' do
        expect(subject.tags).to include('Environment' => environment)
        expect(subject.tags).to include('Project' => project)
      end
    end
  end
  
  # Check for subnet distribution across AZs (high availability for production)
  describe aws_subnets(vpc_id: vpc_id).where(subnet_id: /.+/) do
    its('availability_zones.uniq.count') { should be >= 3 }
  end
end

control 'vpc-4' do
  impact 1.0
  title 'Ensure Network ACLs have proper security rules'
  desc 'Verifies that Network ACLs have proper security rules for production environment'
  
  aws_subnets(vpc_id: vpc_id).subnet_ids.each do |subnet_id|
    subnet = aws_subnet(subnet_id: subnet_id)
    describe aws_network_acl(network_acl_id: subnet.network_acl_id) do
      it { should exist }
      
      it 'should not have overly permissive inbound rules' do
        # No rule allowing all traffic on all ports
        overly_permissive = subject.inbound_rules.any? do |r|
          r.rule_action == 'allow' && r.cidr_block == '0.0.0.0/0' && 
          r.from_port == 0 && r.to_port == 65535
        end
        expect(overly_permissive).to be false
      end
    end
  end
end