# GitLab → Jenkins

Repository:

`https://gitlab.com/SOFTAPP-TECHNOLOGIES/kailash-e-store-real-devops-ci-cd-pipeline.git`

Configure a GitLab webhook to the Jenkins job endpoint required by the Jenkins GitLab integration installed in your Jenkins environment.

The intended flow is:

```text
Git push
  ↓
GitLab webhook
  ↓
Jenkins
  ↓
Jenkinsfile
```
