# Jenkins Configuration

## Required Credentials

Create:

- `rds-db-password` — Secret Text
- `sonar-token` — Secret Text
- `dockerhub-creds` — Username/Password; use a Docker Hub access token as the password

## Pipeline

Point a Pipeline/Multibranch Pipeline job at the GitLab repository:

`https://gitlab.com/SOFTAPP-TECHNOLOGIES/kailash-e-store-real-devops-ci-cd-pipeline.git`

Configure the GitLab webhook to trigger the Jenkins job.

## Tools

The Jenkins EC2 bootstrap installs Terraform, AWS CLI, kubectl, Helm, Trivy, SonarScanner, Docker and Ansible.
