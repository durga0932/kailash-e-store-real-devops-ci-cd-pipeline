# One-Time Bootstrap

## 1. Configure AWS identity on the bootstrap machine

Use an authorised AWS CLI identity/SSO session.

## 2. Enter Terraform directory

```bash
cd terraform
terraform init
terraform validate
terraform plan -var='db_password=YOUR_DB_PASSWORD'
terraform apply -var='db_password=YOUR_DB_PASSWORD'
```

Never commit the real password.

## 3. Read Terraform outputs

```bash
terraform output jenkins_url
terraform output sonarqube_url
terraform output ecr_repository_url
terraform output eks_cluster_name
```

The Jenkins and SonarQube instance IDs are also available for the automated SSM inventory.
