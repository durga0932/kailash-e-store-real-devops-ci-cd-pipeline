#!/usr/bin/env bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl gnupg docker.io
systemctl enable --now docker

# SonarQube is started as a container. Ansible remains responsible for
# operational configuration after bootstrap.
docker volume create sonarqube_data || true
docker volume create sonarqube_logs || true
docker volume create sonarqube_extensions || true

docker rm -f sonarqube 2>/dev/null || true
docker run -d \
  --name sonarqube \
  --restart unless-stopped \
  -p 9000:9000 \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_logs:/opt/sonarqube/logs \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  sonarqube:lts-community

echo "SonarQube bootstrap complete." > /var/log/kailash-sonarqube-bootstrap.txt
