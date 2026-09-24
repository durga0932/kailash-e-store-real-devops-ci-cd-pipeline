# SonarQube

Terraform creates a dedicated SonarQube EC2 instance. The bootstrap starts the LTS Community container and Ansible verifies the service is reachable.

After first login, create an analysis token and store it in Jenkins Credentials as:

`sonar-token`

The Jenkinsfile obtains the SonarQube URL dynamically from Terraform output; no public IP is hard-coded.
