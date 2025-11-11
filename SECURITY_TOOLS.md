# Security Tools Integration

This project uses Jenkins as the primary CI/CD pipeline with several integrated security tools to ensure code quality and security throughout the development lifecycle.

## Integrated Security Tools

### 1. Linting

Language-specific linters are used to ensure code quality and consistency:

- **JavaScript/Node.js**: ESLint with eslint-plugin-security for security-focused linting
- **Python**: Pylint with pylint-security plugin
- **Java**: Checkstyle with XML reporting
- **Terraform**: TFLint for Terraform code linting

The linting stage automatically detects the application type and applies the appropriate linter. All linting results are stored as JUnit XML reports when possible for integration with Jenkins reporting.

### 2. OWASP Dependency Check

[OWASP Dependency Check](https://owasp.org/www-project-dependency-check/) scans application dependencies for known vulnerabilities in:

- Java libraries
- JavaScript/Node.js packages
- Python packages
- .NET assemblies
- Ruby gems
- Infrastructure code dependencies

Key features of our implementation:
- Uses the latest version (8.4.0) of OWASP Dependency Check
- Scans both application code and infrastructure modules
- Generates HTML, XML, JSON, and CSV reports
- Configured with CVSS threshold of 7 for failing builds
- HTML reports are published directly in Jenkins for easy access

### 3. Checkov

[Checkov](https://www.checkov.io/) is a static code analysis tool for Infrastructure-as-Code (IaC) that scans:

- Terraform files with comprehensive policy checks
- CloudFormation templates with AWS-specific security policies
- Kubernetes manifests
- Docker files
- ARM templates

Our implementation includes:
- Always using the latest version via pip install upgrading
- Multiple output formats (CLI, JUnit XML, JSON)
- Specific AWS-focused policy scans (CKV_AWS_*)
- Soft-fail mode to report issues without failing the build
- JUnit XML integration for Jenkins test reporting

### 4. SonarQube

[SonarQube](https://www.sonarqube.org/) provides comprehensive code quality and security analysis:

- Code quality metrics
- Code smells detection
- Security vulnerability scanning
- Test coverage reporting
- Maintainability analysis
- Duplicated code detection
- Infrastructure-as-Code analysis

Our SonarQube integration includes:
- Latest SonarQube scanner (5.0.1)
- Analysis of all project components (app, modules, environments)
- Integration with security reports from other tools
- Terraform code analysis
- Quality gate checking
- Exclusions for non-relevant files

## How to View Reports

Security reports are automatically generated and accessible in multiple ways:

1. **Jenkins Build Artifacts**: From the Jenkins build page, click on "Artifacts"
   - Navigate to the "security-reports" directory for raw reports
   - Navigate to the "lint-reports" directory for linting reports

2. **Jenkins Published Reports**:
   - OWASP Dependency Check: Available as published HTML report
   - JUnit Test Results: Includes results from linting and security tool outputs

3. **SonarQube Dashboard**: Access the SonarQube server to view detailed quality and security metrics.

## Adding Additional Security Tools

To add a new security tool to the pipeline:

1. Add a new stage in the `Security Scan` parallel section of the Jenkinsfile
2. Implement the tool installation and execution steps
3. Configure the tool to output reports to the appropriate directory
4. Add JUnit XML integration where possible
5. Update this documentation file with details about the new tool

## CI/CD Security Best Practices

- Always review security reports before merging code
- Fix identified security issues promptly
- Keep security tools updated to the latest versions (which our pipeline does automatically)
- Run regular security audits on the codebase and infrastructure
- Use Quality Gates in SonarQube to enforce security standards