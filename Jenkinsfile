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
        
        stage('Linting') {
            steps {
                sh 'echo "Running code linting"'
                dir('app') {
                    sh '''
                        # Example for JavaScript/Node.js application
                        if [ -f package.json ]; then
                            echo "Running ESLint"
                            npm install eslint eslint-plugin-security --no-save
                            npx eslint . --ext .js,.jsx,.ts,.tsx --config .eslintrc.js || {
                                echo "ESLint found issues. Creating report..."
                                mkdir -p ../lint-reports
                                npx eslint . --ext .js,.jsx,.ts,.tsx --format junit --output-file ../lint-reports/eslint-report.xml
                                exit 0
                            }
                        # Example for Python application
                        elif [ -f requirements.txt ]; then
                            echo "Running pylint"
                            pip install pylint pylint-security
                            mkdir -p ../lint-reports
                            pylint --recursive=y . --output-format=parseable --reports=y > ../lint-reports/pylint-report.txt || echo "Pylint issues found but continuing"
                        # Example for Java application
                        elif [ -f pom.xml ]; then
                            echo "Running Checkstyle"
                            mvn checkstyle:check -Dcheckstyle.output.format=xml -Dcheckstyle.output.file=../lint-reports/checkstyle-report.xml || echo "Checkstyle issues found but continuing"
                        # Example for Terraform
                        else
                            echo "Running TFLint on terraform files"
                            mkdir -p ../lint-reports
                            curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
                            find .. -name "*.tf" -type f -exec dirname {} \; | sort -u | while read dir; do
                                echo "Running TFLint in $dir"
                                cd $dir && tflint --format junit > $(dirname $(pwd))/lint-reports/tflint-$(basename $(pwd))-report.xml || true
                            done
                        fi
                    '''
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'lint-reports/**', allowEmptyArchive: true
                    junit allowEmptyResults: true, testResults: 'lint-reports/**/*.xml'
                }
            }
        }
        
        stage('Security Scan') {
            parallel {
                stage('OWASP Dependency Check') {
                    steps {
                        sh 'echo "Running OWASP Dependency Check"'
                        // Download and run OWASP dependency check
                        sh '''
                            mkdir -p security-reports
                            # Use the latest version of dependency-check
                            wget -q https://github.com/jeremylong/DependencyCheck/releases/download/v8.4.0/dependency-check-8.4.0-release.zip
                            unzip -q dependency-check-8.4.0-release.zip
                
                            # Run dependency check on both app code and infrastructure code
                            ./dependency-check/bin/dependency-check.sh \
                                --scan app \
                                --scan modules \
                                --project "${PROJECT_NAME}-${ENVIRONMENT}" \
                                --format "HTML" --format "XML" --format "JSON" --format "CSV" \
                                --out security-reports \
                                --failOnCVSS 7
                
                            echo "OWASP Dependency Check complete. Reports available in security-reports directory."
                        '''
                    }
                    post {
                        always {
                            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, keepAll: true, 
                                reportDir: 'security-reports', 
                                reportFiles: 'dependency-check-report.html', 
                                reportName: 'OWASP Dependency Check Report', 
                                reportTitles: ''])
                        }
                    }
                }
        
                stage('Checkov') {
                    steps {
                        sh 'echo "Running Checkov for Infrastructure as Code security scanning"'
                        sh '''
                            # Install/Upgrade Checkov to latest version
                            pip install checkov --upgrade
                
                            # Create reports directory if it doesn't exist
                            mkdir -p security-reports
                
                            # Run Checkov on Terraform files with multiple output formats
                            checkov -d . \
                                --output cli \
                                --output junitxml \
                                --output json \
                                --output-file-path console,security-reports/checkov-report.xml,security-reports/checkov-report.json \
                                --soft-fail \
                                --framework terraform
                
                            # Run specific policy scans for AWS resources
                            echo "Running focused scans on AWS resources..."
                            checkov -d . \
                                --output cli \
                                --framework cloudformation \
                                --check CKV_AWS_* \
                                --soft-fail
                
                            echo "Checkov scanning complete. Reports available in security-reports directory."
                        '''
                    }
                    post {
                        always {
                            junit allowEmptyResults: true, testResults: 'security-reports/checkov-report.xml'
                        }
                    }
                }
        
                stage('SonarQube Analysis') {
                    steps {
                        withSonarQubeEnv('SonarQube') {
                            sh 'echo "Running SonarQube analysis"'
                            sh '''
                                # Install sonar-scanner with latest version
                                if [ ! -d "sonar-scanner" ]; then
                                    wget -q https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
                                    unzip -q sonar-scanner-cli-5.0.1.3006-linux.zip
                                    mv sonar-scanner-5.0.1.3006-linux sonar-scanner
                                fi
                
                                # Configure SonarQube project properties
                                cat > sonar-project.properties << EOL
                                # Project identification
                                sonar.projectKey=${PROJECT_NAME}-${ENVIRONMENT}
                                sonar.projectName=${PROJECT_NAME} ${ENVIRONMENT}
                                sonar.projectVersion=1.0.${BUILD_NUMBER}
                
                                # Source code and test directories
                                sonar.sources=app,modules,environments
                                sonar.tests=app/tests
                
                                # Exclude specific directories
                                sonar.exclusions=**/*.md,**/*.txt,**/node_modules/**,**/.terraform/**
                
                                # Configure test reports
                                sonar.junit.reportPaths=app/target/surefire-reports,**/test-results/**/*.xml
                                sonar.javascript.lcov.reportPaths=app/coverage/lcov.info
                                sonar.coverage.jacoco.xmlReportPaths=app/target/site/jacoco/jacoco.xml
                
                                # Include security reports
                                sonar.dependencyCheck.jsonReportPath=security-reports/dependency-check-report.json
                                sonar.dependencyCheck.htmlReportPath=security-reports/dependency-check-report.html
                
                                # Terraform analysis
                                sonar.terraform.file.suffixes=tf
                                sonar.terraform.activate=true
                
                                # Additional properties
                                sonar.sourceEncoding=UTF-8
                                sonar.verbose=true
                                EOL
                
                                # Run SonarQube analysis
                                ./sonar-scanner/bin/sonar-scanner
                
                                echo "SonarQube analysis complete."
                            '''
                        }
                    }
                    post {
                        always {
                            echo "SonarQube Quality Gate check"
                            timeout(time: 2, unit: 'MINUTES') {
                                waitForQualityGate abortPipeline: false
                            }
                        }
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'security-reports/**', allowEmptyArchive: true
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
    
            // Archive security reports
            archiveArtifacts artifacts: 'security-reports/**', allowEmptyArchive: true
            junit allowEmptyResults: true, testResults: 'security-reports/**/*.xml'
    
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