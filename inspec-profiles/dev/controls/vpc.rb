title 'VPC Compliance Checks'

vpc_id = input('vpc_id')
environment = input('environment')
project = input('project')

control 'vpc-1' do
  impact 1.0
  title 'Ensure VPC is properly configured'
  desc 'Verifies that the VPC exists and has the proper configuration'
  
  describe aws_vpc(vpc_id) do
    it { should exist }
    its('cidr_block') { should eq '10.0.0.0/16' }
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
  end
end

control 'vpc-3' do
  impact 0.7
  title 'Ensure subnets are properly configured'
  desc 'Verifies that subnets are properly configured with appropriate CIDRs and tags'
  
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
end