# Production Hardening

The current package is a fully automated reference architecture. Before client production use:

1. Replace broad Jenkins IAM permissions with least privilege.
2. Put Terraform state in a protected S3 backend and use an appropriate locking/state-protection strategy.
3. Store RDS and application secrets in AWS Secrets Manager.
4. Restrict Jenkins and SonarQube access; avoid open management ports where possible.
5. Add AWS Load Balancer Controller + ALB/Ingress for EKS.
6. Add ACM TLS, Route 53, CloudFront and WAF.
7. Separate infrastructure and application release pipelines for controlled production changes.
8. Add backup/restore testing and disaster-recovery procedures.
