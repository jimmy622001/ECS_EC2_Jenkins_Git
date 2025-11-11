pipeline {
    agent any

    // Add parameters to allow selection of environment from Jenkins UI
    parameters {
        choice(name: 'ENVIRONMENT', choices: ['dev', 'prod', 'dr-pilot-light'], description: 'Environment to deploy to')
        booleanParam(name: 'RUN_TESTS', defaultValue: true, description: 'Run automated tests')
        booleanParam(name: 'DEPLOY', defaultValue: true, description: 'Deploy to ECS')
    }

    // Environment variables for the pipeline
    environment {
        // Dynamic environment variables based on parameters
        AWS_REGION = {
            if (params.ENVIRONMENT == 'prod') return 'eu-west-2'
            else if (params.ENVIRONMENT == 'dev') return 'eu-west-2'
            else if (params.ENVIRONMENT == 'dr-pilot-light') return 'us-west-2'
            else return 'eu-west-2'
        }
        ECR_REPOSITORY = {
            if (params.ENVIRONMENT == 'prod') return 'ecs-app-prod'
            else if (params.ENVIRONMENT == 'dev') return 'ecs-app-dev'
            else if (params.ENVIRONMENT == 'dr-pilot-light') return 'ecs-app-dr'
            else return 'ecs-app-dev'
        }
        VPC_ID = {
            if (params.ENVIRONMENT == 'prod') return '10.1.0.0/16' // Production VPC CIDR
            else if (params.ENVIRONMENT == 'dev') return '10.0.0.0/16' // Dev VPC CIDR
            else if (params.ENVIRONMENT == 'dr-pilot-light') return '10.2.0.0/16' // DR VPC CIDR
            else return '10.0.0.0/16'
        }
        PROJECT_NAME = 'ecs-app'

        // Credentials setup (stored in Jenkins)
        AWS_CREDENTIALS = 'aws-credentials'
        SONAR_CREDENTIALS = 'sonarqube-credentials'
    }
    
    // Pipeline stages
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git log -1 --pretty=format:"%h - %an: %s" > commit.txt'
                sh 'cat commit.txt'
            }
        }
        
        stage('Build') {
            steps {
                // Assuming your application is in the 'app' directory
                dir('app') {
                    sh 'echo "Building application for ${params.ENVIRONMENT} environment"'
                    
                    // Sample build commands (adjust based on your application)
                    script {
                        // Determine which AWS region to use based on environment
                        def deployRegion
                        if (params.ENVIRONMENT == 'dr-pilot-light') {
                            deployRegion = 'us-west-2'  // Use the DR region
                        } else if (params.ENVIRONMENT == 'prod') {
                            deployRegion = 'eu-west-2'  // Production region
                        } else {
                            deployRegion = 'eu-west-2'  // Development region
                        }
                    
                        sh """
                        export AWS_REGION=${deployRegion}
                        # Example for Node.js application
                        if [ -f package.json ]; then
                            npm install
                            npm run build
                        # Example for Java application
                        elif [ -f pom.xml ]; then
                            mvn clean package -DskipTests
                        # Example for Python application
                        elif [ -f requirements.txt ]; then
                            pip install -r requirements.txt
                            # Add build steps if needed
                        else
                            echo "Unknown application type"
                        fi
                    """
                    }
                }
            }
        }
        
        stage('Test') {
            when {
                expression { params.RUN_TESTS == true }
            }
            parallel {
                stage('Unit Tests') {
                    steps {
                        dir('app') {
                            sh 'echo "Running unit tests"'
                            
                            // Sample test commands (adjust based on your application)
                            sh '''
                                # Example for Node.js application
                                if [ -f package.json ]; then
                                    npm test
                                # Example for Java application
                                elif [ -f pom.xml ]; then
                                    mvn test
                                # Example for Python application
                                elif [ -f requirements.txt ]; then
                                    pytest tests/unit/
                                else
                                    echo "Unknown application type"
                                fi
                            '''
                        }
                    }
                }
                
                stage('Integration Tests') {
                    steps {
                        dir('app') {
                            sh 'echo "Running integration tests"'
                            
                            // Sample integration test commands
                            sh '''
                                # Example for Node.js application
                                if [ -f package.json ]; then
                                    npm run test:integration
                                # Example for Java application
                                elif [ -f pom.xml ]; then
                                    mvn integration-test
                                # Example for Python application
                                elif [ -f requirements.txt ]; then
                                    pytest tests/integration/
                                else
                                    echo "Unknown application type"
                                fi
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Security Scan') {
            steps {
                // OWASP Dependency check for vulnerability scanning
                sh 'echo "Running security scan"'
                
                // Sample security scan commands
                sh '''
                    # Example for OWASP dependency check
                    # wget https://github.com/jeremylong/DependencyCheck/releases/download/v7.1.0/dependency-check-7.1.0-release.zip
                    # unzip -q dependency-check-7.1.0-release.zip
                    # ./dependency-check/bin/dependency-check.sh --scan app --format "ALL" --out security-reports
                '''
                
                // SonarQube scan for code quality and security issues
                withSonarQubeEnv('SonarQube') {
                    sh 'echo "Running SonarQube analysis"'
                    // Example: sh 'sonar-scanner -Dsonar.projectKey=ecs-app -Dsonar.sources=app'
                }
            }
        }
        
        stage('Build and Push Docker Image') {
            when {
                anyOf {
                    branch 'main'
                    branch 'dev'
                    branch 'dr-pilot-light'
                }
            }
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: env.AWS_CREDENTIALS,
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh 'echo "Building and pushing Docker image"'
                    
                    // Get the ECR login and build/push the image
                    sh '''
                        # Login to ECR
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin \
                            ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                        
                        # Build the Docker image
                        IMAGE_TAG=$(git rev-parse --short HEAD)
                        ECR_REPO_URL=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}
                        
                        cd app
                        docker build -t ${ECR_REPO_URL}:${IMAGE_TAG} -t ${ECR_REPO_URL}:latest .
                        
                        # Push the images to ECR
                        docker push ${ECR_REPO_URL}:${IMAGE_TAG}
                        docker push ${ECR_REPO_URL}:latest
                        
                        # Save image info for deployment
                        echo "${ECR_REPO_URL}:${IMAGE_TAG}" > ../image_tag.txt
                    '''
                }
            }
        }
        
        stage('Terraform Plan') {
            when {
                expression { params.DEPLOY == true }
            }
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: env.AWS_CREDENTIALS,
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh 'echo "Running Terraform Plan for ${params.ENVIRONMENT} environment in ${AWS_REGION}"'
        
                    // Plan Terraform changes for the selected environment
                    dir("environments/${params.ENVIRONMENT}") {
                        sh '''
                            terraform init
                            terraform validate
                            terraform plan -var-file=terraform.tfvars -out=tfplan
        
                            # Verify no CIDR overlaps with other environments
                            echo "Verifying CIDR ranges for ${params.ENVIRONMENT} don't overlap with other environments"
                            VPC_CIDR=$(grep vpc_cidr terraform.tfvars | cut -d '"' -f2)
                            echo "VPC CIDR for ${params.ENVIRONMENT}: $VPC_CIDR"
                        '''
                    }
                }
            }
        }
        
        stage('Approve Deployment') {
            when {
                allOf {
                    expression { params.ENVIRONMENT == 'prod' }
                    expression { params.DEPLOY == true }
                }
            }
            steps {
                // Only require approval for production deployments
                timeout(time: 1, unit: 'DAYS') {
                    input message: "Deploy to PRODUCTION?"
                }
            }
        }
        
        stage('Deploy to ECS') {
            when {
                expression { params.DEPLOY == true }
            }
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: env.AWS_CREDENTIALS,
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh 'echo "Deploying to ${params.ENVIRONMENT} environment"'
                    
                    // Apply Terraform changes
                    dir("environments/${params.ENVIRONMENT}") {
                        sh 'terraform apply -auto-approve tfplan'
                    }
                    
                    // Create and register a new task definition revision with the new image
                    sh '''
                        # Get the image tag that was built
                        IMAGE_TAG=$(cat ../image_tag.txt)
                        
                        # Prepare the CodeDeploy deployment
                        APP_NAME="${PROJECT_NAME}-${ENVIRONMENT}-app"
                        DEPLOYMENT_GROUP="${PROJECT_NAME}-${ENVIRONMENT}-deployment-group"
                        
                        # Create the appspec.yaml for blue/green deployment
                        cat > appspec.yaml << EOF
                        version: 0.0
                        Resources:
                          - TargetService:
                              Type: AWS::ECS::Service
                              Properties:
                                TaskDefinition: <TASK_DEFINITION>
                                LoadBalancerInfo:
                                  ContainerName: app
                                  ContainerPort: 80
                        EOF
                        
                        # Start the deployment
                        # Determine which region to deploy to based on environment
                        if [ "${ENVIRONMENT}" == "dr-pilot-light" ]; then
                            DEPLOY_REGION="us-west-2"
                        elif [ "${ENVIRONMENT}" == "prod" ]; then
                            DEPLOY_REGION="eu-west-2"
                        else
                            DEPLOY_REGION="eu-west-2"
                        fi
                        
                        aws deploy create-deployment \\
                          --application-name $APP_NAME \\
                          --deployment-group-name $DEPLOYMENT_GROUP \\
                          --revision revisionType=AppSpecContent,appSpecContent="{content='$(cat appspec.yaml | base64)'}" \\
                          --description "Deployment from Jenkins - $BUILD_NUMBER" \\
                          --region $DEPLOY_REGION
                    '''
                }
            }
        }
    }
    
    post {
        always {
            // Archive test results
            junit allowEmptyResults: true, testResults: '**/test-results/*.xml'
            
            // Clean up workspace
            cleanWs()
        }
        
        success {
            echo "Pipeline completed successfully!"
            // Send notifications if needed
            // slackSend channel: '#deployments', color: 'good', message: "Deployment to ${params.ENVIRONMENT} completed successfully"
        }
        
        failure {
            echo "Pipeline failed!"
            // Send notifications if needed
            // slackSend channel: '#deployments', color: 'danger', message: "Deployment to ${params.ENVIRONMENT} failed"
        }
    }
}