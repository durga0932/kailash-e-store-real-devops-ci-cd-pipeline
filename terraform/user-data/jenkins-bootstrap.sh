#!/usr/bin/env bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  ca-certificates curl gnupg unzip git wget jq \
  python3 python3-pip python3-venv \
  openjdk-21-jre-headless ansible docker.io

systemctl enable --now docker

# ------------------------------------------------------------
# Jenkins
# ------------------------------------------------------------
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key | \
  tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list

apt-get update
apt-get install -y jenkins
usermod -aG docker jenkins

# ------------------------------------------------------------
# AWS CLI v2
# ------------------------------------------------------------
if ! command -v aws >/dev/null 2>&1; then
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  rm -rf /tmp/aws
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install
  rm -rf /tmp/aws /tmp/awscliv2.zip
fi

# ------------------------------------------------------------
# Terraform
# ------------------------------------------------------------
if ! command -v terraform >/dev/null 2>&1; then
  curl -fsSL https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "$VERSION_CODENAME") main" \
    > /etc/apt/sources.list.d/hashicorp.list
  apt-get update
  apt-get install -y terraform
fi

# ------------------------------------------------------------
# kubectl
# ------------------------------------------------------------
if ! command -v kubectl >/dev/null 2>&1; then
  KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
  curl -L -o /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
  rm -f /tmp/kubectl
fi

# ------------------------------------------------------------
# Helm
# ------------------------------------------------------------
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# ------------------------------------------------------------
# Trivy
# ------------------------------------------------------------
if ! command -v trivy >/dev/null 2>&1; then
  wget -qO- https://aquasecurity.github.io/trivy-repo/deb/public.key | \
    gpg --dearmor -o /usr/share/keyrings/trivy.gpg
  echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
    > /etc/apt/sources.list.d/trivy.list
  apt-get update
  apt-get install -y trivy
fi

# ------------------------------------------------------------
# SonarScanner CLI
# ------------------------------------------------------------
SCANNER_VERSION="7.1.0.4889"
if ! command -v sonar-scanner >/dev/null 2>&1; then
  curl -fsSL "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SCANNER_VERSION}-linux-x64.zip" \
    -o /tmp/sonar-scanner.zip
  unzip -q /tmp/sonar-scanner.zip -d /opt
  ln -sf "/opt/sonar-scanner-${SCANNER_VERSION}-linux-x64/bin/sonar-scanner" /usr/local/bin/sonar-scanner
  rm -f /tmp/sonar-scanner.zip
fi

# AWS SDK helpers for Ansible/SSM workflows.
python3 -m pip install --break-system-packages boto3 botocore

systemctl daemon-reload
systemctl enable --now jenkins
systemctl restart jenkins

cat > /etc/profile.d/kailash-devops.sh <<'PROFILE'
export AWS_PAGER=""
PROFILE

echo "Jenkins bootstrap complete." > /var/log/kailash-jenkins-bootstrap.txt
