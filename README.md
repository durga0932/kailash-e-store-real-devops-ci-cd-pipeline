# Kailash E-Store — Final AWS DevSecOps Automation

GitLab repository:

`https://gitlab.com/SOFTAPP-TECHNOLOGIES/kailash-e-store-real-devops-ci-cd-pipeline.git`

Docker Hub mirror:

`shivsoftapp/kailash-e-store`

## Final repository layout

```text
.
├── Jenkinsfile
├── Dockerfile
├── sonar-project.properties
├── tests/
├── ansible/
│   ├── playbook.yml
│   ├── requirements.yml
│   ├── inventory.ini.example
│   └── README.md
├── terraform/
│   ├── master.tf                 # combined AWS infrastructure
│   │   │   └── user-data/
│       ├── jenkins-bootstrap.sh
│       └── sonarqube-bootstrap.sh
├── helm/
│   └── kailash-e-store/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── _helpers.tpl
│           ├── deployment.yaml
│           ├── service.yaml
│           └── hpa.yaml
└── monitoring/
    └── kube-prometheus-stack-values.yaml
```

## Terraform master.tf

`terraform/master.tf` is intentionally combined. It creates:

1. VPC, public/private subnets and NAT
2. Jenkins IAM role + EC2
3. SonarQube IAM role + EC2
4. ECR repository
5. Private S3 media bucket
6. PostgreSQL RDS
7. ElastiCache Redis
8. EKS cluster + managed node group
9. EKS access for Jenkins
10. Outputs used by Jenkins/Ansible

Jenkins is also the Ansible controller. There is no separate Ansible EC2.

## Ansible files

### `ansible/playbook.yml`
Configures the Jenkins controller and SonarQube server.

### `ansible/requirements.yml`
Installs:

- `amazon.aws`
- `community.docker`

### `ansible/inventory.ini.example`
Template only. Jenkins generates the real `inventory.ini` from Terraform EC2 instance IDs.

### `ansible/README.md`
Explains the Ansible/SSM workflow.

No `.pem` SSH key is required for the Ansible connection.

## One-time AWS bootstrap

The first infrastructure creation still needs a trusted AWS identity. From an authorised bootstrap workstation:

```bash
cd terraform
terraform init
terraform validate
terraform plan -var='db_password=YOUR_DB_PASSWORD'
terraform apply -var='db_password=YOUR_DB_PASSWORD'
```

Do not put the real password in Git. Prefer `TF_VAR_db_password` or a secret manager/Jenkins credential.

After Jenkins is available, the Jenkins pipeline can manage the end-to-end workflow.

## Jenkins credentials required

Create these Jenkins Credentials IDs:

1. `rds-db-password` — Secret Text containing the RDS password.
2. `sonar-token` — Secret Text containing a SonarQube analysis token.
3. `dockerhub-creds` — Username/Password where the password is a Docker Hub access token.

Do not paste these secrets into GitLab or into `Jenkinsfile`.

## Jenkins tools / plugins

The Jenkins EC2 bootstrap installs:

- Jenkins
- Docker
- AWS CLI v2
- Terraform
- kubectl
- Helm
- Trivy
- SonarScanner CLI
- Ansible
- Python tooling

Jenkins also needs the normal Pipeline/Credentials/SCM plugins required by the configured job. The SonarQube scan in this final pipeline uses `sonar-scanner` directly, so it does not depend on a Jenkins SonarQube installation name.

## Pipeline flow

```text
GitLab
  ↓ webhook
Jenkins EC2
  ↓
Terraform
  ↓
Ansible + AWS SSM
  ↓
Django Test
  ↓
SonarQube
  ↓
Trivy filesystem
  ↓
Docker build
  ↓
Trivy image
  ↓
Amazon ECR
  ↓
Docker Hub mirror
  ↓
Helm
  ↓
Amazon EKS
  ↓
Health verification
  ↓
Prometheus + Grafana
```

## Important production notes

This package is a fully automated reference/lab architecture. Before using it for a real client production account:

- replace Jenkins `PowerUserAccess` with least-privilege IAM;
- use a dedicated Terraform execution role;
- move Terraform state to an S3 backend with appropriate locking/state protection;
- keep database secrets in AWS Secrets Manager or an equivalent secret workflow;
- restrict Jenkins/SonarQube network access;
- use an AWS Load Balancer Controller + ALB/Ingress for EKS rather than exposing a Service LoadBalancer directly;
- add ACM HTTPS, Route 53, CloudFront and WAF;
- separate infrastructure changes from application releases and add an approval gate for production infrastructure changes;
- use private management hosts/endpoints where appropriate.
