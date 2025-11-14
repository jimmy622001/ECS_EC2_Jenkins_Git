title 'ECS Cluster Compliance Checks - Production'

environment = input('environment')
project = input('project')
cluster_name = "#{project}-#{environment}-cluster"

control 'ecs-1' do
  impact 1.0
  title 'Ensure ECS cluster is properly configured for production'
  desc 'Verifies that the ECS cluster exists and is active with proper production settings'
  
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
  title 'Ensure ECS task definitions have proper security configuration for production'
  desc 'Verifies that the ECS task definitions have proper security settings for production'
  
  task_def_name = "#{project}-#{environment}-task"
  
  describe aws_ecs_task_definition(task_definition_name: task_def_name) do
    it { should exist }
    its('status') { should eq 'ACTIVE' }
    its('network_mode') { should eq 'bridge' }
    its('container_definitions') { should_not be_empty }
    
    # Production-specific checks
    its('cpu') { should be >= 512 } # Ensure adequate CPU for production workloads
    its('memory') { should be >= 1024 } # Ensure adequate memory for production workloads
    
    it 'has container definitions with non-privileged execution' do
      container_defs = JSON.parse(subject.container_definitions)
      container_defs.each do |container|
        expect(container['privileged']).to be_nil.or be false
        
        # Check resource allocations for containers
        expect(container['cpu']).to be >= 256
        expect(container['memory']).to be >= 512
      end
    end
    
    it 'has appropriate security configuration' do
      container_defs = JSON.parse(subject.container_definitions)
      container_defs.each do |container|
        # Ensure read-only root filesystem where possible
        expect(container['readonlyRootFilesystem']).to be_nil.or be true
        
        # Ensure no unnecessary host access
        expect(container['linuxParameters']).to be_nil.or_not include('capabilities' => hash_including('add' => include('SYS_ADMIN')))
      end
    end
  end
end

control 'ecs-3' do
  impact 1.0
  title 'Ensure proper logging is configured for containers in production'
  desc 'Verifies that log configuration is properly set up for containers in production'
  
  task_def_name = "#{project}-#{environment}-task"
  
  describe aws_ecs_task_definition(task_definition_name: task_def_name) do
    it 'has a log configuration using awslogs with appropriate retention' do
      container_defs = JSON.parse(subject.container_definitions)
      container_defs.each do |container|
        expect(container['logConfiguration']['logDriver']).to eq 'awslogs'
        expect(container['logConfiguration']['options']['awslogs-stream-prefix']).to eq 'ecs'
        expect(container['logConfiguration']['options']['awslogs-region']).to eq 'eu-west-2' # Production region
      end
    end
  end
end

control 'ecs-4' do
  impact 1.0
  title 'Ensure ECS services are properly configured for production'
  desc 'Verifies that ECS services are properly configured and running on the cluster with high availability'
  
  service_name = "#{project}-#{environment}-service"
  
  describe aws_ecs_service(cluster: cluster_name, service_name: service_name) do
    it { should exist }
    its('status') { should eq 'ACTIVE' }
    its('desired_count') { should be >= 2 } # Ensure minimum of 2 tasks for high availability in production
    its('running_count') { should cmp subject.desired_count } # All required tasks should be running
    its('launch_type') { should eq 'EC2' }
    its('service_name') { should eq service_name }
    
    # Check appropriate deployment configuration
    its('deployment_configuration.deployment_circuit_breaker.enable') { should be true }
    its('deployment_configuration.deployment_circuit_breaker.rollback') { should be true }
    its('deployment_configuration.minimum_healthy_percent') { should be >= 50 }
    its('deployment_configuration.maximum_percent') { should be >= 200 }
    
    it 'has proper load balancer configuration' do
      expect(subject.load_balancers).not_to be_empty
      expect(subject.load_balancers.first['container_name']).not_to be_nil
      expect(subject.load_balancers.first['container_port']).not_to be_nil
    end
  end
end

control 'ecs-5' do
  impact 1.0
  title 'Ensure ECS Auto Scaling is properly configured for production'
  desc 'Verifies that ECS Auto Scaling is properly configured for production workloads'
  
  # Check for Auto Scaling target
  service_resource_id = "service/#{cluster_name}/#{project}-#{environment}-service"
  
  describe aws_appautoscaling_target(service_namespace: 'ecs', resource_id: service_resource_id) do
    it { should exist }
    its('min_capacity') { should be >= 2 } # Minimum of 2 tasks for high availability
    its('max_capacity') { should be >= 4 } # Allow scaling up to handle load
  end
  
  # Check for Auto Scaling policies
  describe aws_appautoscaling_policies(service_namespace: 'ecs') do
    it { should exist }
    its('names') { should include /#{project}-#{environment}-scale-(up|down)/ }
  end
end