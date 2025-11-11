# GitHub Workflows Are Disabled

This directory contains disabled GitHub Actions workflows. All CI/CD operations have been migrated to Jenkins pipelines as defined in the project's `Jenkinsfile`.

## Why are these files here?

These workflows are kept in a disabled state to:
1. Prevent any accidental workflow runs
2. Document the migration from GitHub Actions to Jenkins
3. Preserve the workflow history while preventing new executions

## Jenkins Pipeline

The Jenkins pipeline configuration can be found in the `Jenkinsfile` in the root of this repository. It includes:
- Linting
- Checkov security scanning
- OWASP dependency check
- SonarQube analysis

For more information on the security tools used in this project, see `SECURITY_TOOLS.md`.