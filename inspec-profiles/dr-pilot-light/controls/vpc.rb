title 'VPC Compliance Checks - DR Environment'

vpc_id = input('vpc_id')
environment = input('environment')
project = input('project')

control 'vpc-1' do
  impact 1.0
  title 'Ensure DR VPC is properly configured'
  desc 'Verifies that the DR VPC exists and has the proper configuration for disaster recovery'
  
  describe aws_vpc(vpc_id) do
    it { should exist }
    its('cidr_block') { should eq '10.2.0.0/16' } # DR CIDR should not overlap with primary regions
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
  title 'Ensure DR VPC has proper network configuration'
  desc 'Verifies that the DR VPC has proper subnet configuration for failover capability'
  
  # Check for presence of subnets in multiple AZs
  describe aws_subnets(vpc_id: vpc_id).where(subnet_id: /.+/) do
    its('availability_zones.uniq.count') { should be >= 2 }  # DR should have multiple AZs
  end
  
  # Check subnet allocations for each type
  describe aws_subnets.where(vpc_id: vpc_id) do
    it { should exist }
    
    # DR should have the same subnet types as primary region
    it 'should have public subnets' do
      public_subnets = subject.where(subnet_id: /.+/).where do |subnet|
        subnet.tags.include?('Type') && subnet.tags['Type'] == 'Public'
      end
      expect(public_subnets.count).to be >= 2
    end
    
    it 'should have private subnets' do
      private_subnets = subject.where(subnet_id: /.+/).where do |subnet|
        subnet.tags.include?('Type') && subnet.tags['Type'] == 'Private'
      end
      expect(private_subnets.count).to be >= 2
    end
    
    it 'should have database subnets' do
      db_subnets = subject.where(subnet_id: /.+/).where do |subnet|
        subnet.tags.include?('Type') && subnet.tags['Type'] == 'Database'
      end
      expect(db_subnets.count).to be >= 2
    end
  end
end

control 'vpc-3' do
  impact 1.0
  title 'Ensure DR VPC has proper route tables and NAT gateways'
  desc 'Verifies that the DR VPC has proper routing configuration'
  
  # Check if internet gateway exists
  describe aws_route_tables.where(vpc_id: vpc_id) do
    it { should exist }
    
    it 'should have routes to internet gateway for public subnets' do
      public_route_table = subject.where(vpc_id: vpc_id).where do |rt|
        rt.routes.any? { |r| r['gateway_id'] && r['gateway_id'].start_with?('igw-') }
      end
      expect(public_route_table.count).to be >= 1
    end
    
    it 'should have routes to NAT gateway for private subnets' do
      private_route_table = subject.where(vpc_id: vpc_id).where do |rt|
        rt.routes.any? { |r| r['nat_gateway_id'] && r['nat_gateway_id'].start_with?('nat-') }
      end
      expect(private_route_table.count).to be >= 1
    end
  end
  
  # Check if NAT gateways exist
  describe aws_nat_gateways.where(vpc_id: vpc_id) do
    it { should exist }
    its('states') { should_not include 'failed' }
    its('count') { should be >= 1 } # At least one NAT gateway in DR region
  end
end