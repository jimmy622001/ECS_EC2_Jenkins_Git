title 'ECS Cluster Compliance Checks'

environment = input('environment')
project = input('project')
cluster_name = "#{project}-#{environment}-cluster"

control 'ecs-1' do
  impact 1.0
  title 'Ensure ECS cluster is properly configured'
  desc 'Verifies that the ECS cluster exists and is active'
  
  describe aws_ecs_cluster(cluster_name: cluster_name) do
    it { should exist }
    its('status') { should eq 'ACTIVE' }
    its('cluster_name') { should eq cluster_name }
    
    it 'should have container insights enabled' do
      # Check the cluster settings for container insights
      expect(subject.settings.detect { |s| s['name'] == 'containerInsights' }['value']).to eq('enabled')
    end
  end
end

control 'ecs-2' do
  impact 1.0
  title 'Ensure ECS task definitions have proper security configuration'
  desc 'Verifies that the ECS task definitions have proper security settings'
  
  task_def_name = "#{project}-#{environment}-task"
  
  describe aws_ecs_task_definition(task_definition_name: task_def_name) do
    it { should exist }
    its('status') { should eq 'ACTIVE' }
    its('network_mode') { should eq 'bridge' }
    its('container_definitions') { should_not be_empty }
    
    it 'has container definitions with non-privileged execution' do
      container_defs = JSON.parse(subject.container_definitions)
      container_defs.each do |container|
        expect(container['privileged']).to be_nil.or be false
      end
    end
  end
end

control 'ecs-3' do
  impact 1.0
  title 'Ensure proper logging is configured for containers'
  desc 'Verifies that log configuration is properly set up for containers'
  
  task_def_name = "#{project}-#{environment}-task"
  
  describe aws_ecs_task_definition(task_definition_name: task_def_name) do
    it 'has a log configuration using awslogs' do
      container_defs = JSON.parse(subject.container_definitions)
      container_defs.each do |container|
        expect(container['logConfiguration']['logDriver']).to eq 'awslogs'
        expect(container['logConfiguration']['options']['awslogs-stream-prefix']).to eq 'ecs'
      end
    end
  end
end

control 'ecs-4' do
  impact 1.0
  title 'Ensure ECS services are properly configured'
  desc 'Verifies that ECS services are properly configured and running on the cluster'
  
  service_name = "#{project}-#{environment}-service"
  
  describe aws_ecs_service(cluster: cluster_name, service_name: service_name) do
    it { should exist }
    its('status') { should eq 'ACTIVE' }
    its('desired_count') { should be >= 1 }
    its('running_count') { should be >= 1 }
    its('launch_type') { should eq 'EC2' }
    its('service_name') { should eq service_name }
    
    it 'has proper load balancer configuration' do
      expect(subject.load_balancers).not_to be_empty
      expect(subject.load_balancers.first['container_name']).not_to be_nil
      expect(subject.load_balancers.first['container_port']).not_to be_nil
    end
  end
end