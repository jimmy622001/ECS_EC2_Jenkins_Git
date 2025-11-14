// AWS FIS experiment Jenkins pipeline for dev environment
pipeline {
    agent any
    
    parameters {
        choice(name: 'EXPERIMENT_TYPE', choices: ['cpu-stress', 'task-termination', 'network-latency'], description: 'Type of FIS experiment to run')
        string(name: 'CUSTOM_DESCRIPTION', defaultValue: 'Scheduled resilience test', description: 'Description for this experiment run')
    }
    
    environment {
        EXPERIMENT_TEMPLATES = [
            'cpu-stress': '',      // To be populated during setup
            'task-termination': '', // To be populated during setup
            'network-latency': ''   // To be populated during setup
        ]
    }
    
    triggers {
        // Run weekly on Thursdays at 2 AM (dev environment only)
        cron('0 2 * * 4')
    }
    
    stages {
        stage('Setup') {
            when {
                expression { return env.BRANCH_NAME == 'develop' || params.EXPERIMENT_TYPE != null }
            }
            
            steps {
                echo "Setting up FIS experiment for dev environment"
                
                // Fetch experiment template IDs
                script {
                    def templateOutput = sh(script: 'aws fis list-experiment-templates --query "experimentTemplates[*].{id:id,tags:tags,description:description}"', returnStdout: true).trim()
                    def templates = readJSON text: templateOutput
                    
                    for (template in templates) {
                        for (tag in template.tags) {
                            if (tag.key == 'Name') {
                                if (tag.value == 'dev-cpu-stress-test') {
                                    env.EXPERIMENT_TEMPLATES['cpu-stress'] = template.id
                                } else if (tag.value == 'dev-task-termination-test') {
                                    env.EXPERIMENT_TEMPLATES['task-termination'] = template.id
                                } else if (tag.value == 'dev-network-latency-test') {
                                    env.EXPERIMENT_TEMPLATES['network-latency'] = template.id
                                }
                            }
                        }
                    }
                    
                    echo "Found template IDs:"
                    echo "CPU Stress: ${env.EXPERIMENT_TEMPLATES['cpu-stress']}"
                    echo "Task Termination: ${env.EXPERIMENT_TEMPLATES['task-termination']}"
                    echo "Network Latency: ${env.EXPERIMENT_TEMPLATES['network-latency']}"
                }
            }
        }
        
        stage('Verify Templates') {
            when {
                expression { return env.BRANCH_NAME == 'develop' || params.EXPERIMENT_TYPE != null }
            }
            
            steps {
                script {
                    def templateId = env.EXPERIMENT_TEMPLATES[params.EXPERIMENT_TYPE]
                    if (templateId == '') {
                        error "No template ID found for experiment type: ${params.EXPERIMENT_TYPE}. Run the setup_aws_fis_dev.sh script first."
                    }
                    
                    echo "Using template ID: ${templateId}"
                }
            }
        }
        
        stage('Run FIS Experiment') {
            when {
                expression { return env.BRANCH_NAME == 'develop' || params.EXPERIMENT_TYPE != null }
            }
            
            steps {
                echo "Running FIS experiment in dev environment"
                
                script {
                    def templateId = env.EXPERIMENT_TEMPLATES[params.EXPERIMENT_TYPE]
                    def description = params.CUSTOM_DESCRIPTION
                    
                    // Run the experiment
                    sh "chmod +x scripts/run_dev_fis_experiment.sh"
                    sh "scripts/run_dev_fis_experiment.sh ${templateId} \"${description}\""
                }
            }
        }
        
        stage('Generate Report') {
            when {
                expression { return env.BRANCH_NAME == 'develop' || params.EXPERIMENT_TYPE != null }
            }
            
            steps {
                echo "Generating FIS experiment report"
                
                // Find the latest log file
                script {
                    def logFile = sh(script: 'ls -t logs/fis/report-*.md | head -1', returnStdout: true).trim()
                    
                    if (logFile) {
                        // Archive the report
                        archiveArtifacts artifacts: logFile, fingerprint: true
                        
                        // Display report summary
                        echo "Report generated: ${logFile}"
                        sh "cat ${logFile}"
                    } else {
                        echo "No report file found"
                    }
                }
            }
        }
        
        stage('Send Notification') {
            when {
                expression { return env.BRANCH_NAME == 'develop' || params.EXPERIMENT_TYPE != null }
            }
            
            steps {
                echo "Sending notification about FIS experiment completion"
                
                // Send email notification (adjust as needed)
                emailext (
                    subject: "FIS Experiment Completed: ${params.EXPERIMENT_TYPE}",
                    body: """
                        <p>AWS FIS experiment has completed in the dev environment.</p>
                        <p><b>Experiment Type:</b> ${params.EXPERIMENT_TYPE}</p>
                        <p><b>Description:</b> ${params.CUSTOM_DESCRIPTION}</p>
                        <p>See attached report or check Jenkins artifacts for details.</p>
                    """,
                    attachmentsPattern: 'logs/fis/report-*.md',
                    to: 'devteam@example.com'
                )
            }
        }
    }
    
    post {
        always {
            echo "FIS experiment pipeline completed"
            cleanWs()
        }
        
        failure {
            echo "FIS experiment pipeline failed"
            
            // Send failure notification
            emailext (
                subject: "FAILED: FIS Experiment in Dev Environment",
                body: """
                    <p>AWS FIS experiment pipeline has failed.</p>
                    <p><b>Experiment Type:</b> ${params.EXPERIMENT_TYPE}</p>
                    <p>Check Jenkins logs for details.</p>
                """,
                to: 'devteam@example.com'
            )
        }
    }
}