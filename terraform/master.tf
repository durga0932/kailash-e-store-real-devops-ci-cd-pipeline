# ============================================================
# KAILASH E-STORE - SINGLE COMBINED TERRAFORM FILE
# ============================================================
# Complete AWS infrastructure:
# VPC/NAT, Jenkins, SonarQube, ECR, S3, RDS PostgreSQL,
# ElastiCache Redis and Amazon EKS.
#
# Terraform state is stored remotely in S3.
#
# Jenkins is the CI/CD + Ansible control node.
# ============================================================


# ============================================================
# 0. TERRAFORM CONFIGURATION + REMOTE STATE
# ============================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "kailash-e-store-prod-tfstate-518056141688"
    key          = "kailash-e-store/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}


# ============================================================
# PROVIDER
# ============================================================

provider "aws" {
  region = var.aws_region
}


# ============================================================
# VARIABLES
# ============================================================

variable "aws_region" {
  description = "Primary AWS region."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "kailash-e-store"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.50.0.0/16"
}

variable "jenkins_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "sonarqube_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "redis_node_type" {
  type    = string
  default = "cache.t4g.micro"
}

variable "db_name" {
  type    = string
  default = "kailashestore"
}

variable "db_username" {
  type    = string
  default = "estoreadmin"
}

variable "db_password" {
  description = "Pass through TF_VAR_db_password or Jenkins secret. Never commit it."
  type        = string
  sensitive   = true
}

variable "create_nat_gateway" {
  type    = bool
  default = true
}

variable "jenkins_allowed_cidr" {
  description = "CIDR allowed to reach Jenkins on TCP/8080."
  type        = string
  default     = "0.0.0.0/0"
}

variable "sonarqube_admin_cidr" {
  description = "CIDR allowed to open SonarQube UI on TCP/9000."
  type        = string
  default     = "0.0.0.0/0"
}

variable "eks_kubernetes_version" {
  type    = string
  default = "1.33"
}

variable "eks_node_instance_type" {
  type    = string
  default = "t3.medium"
}


# ============================================================
# LOCALS
# ============================================================

locals {
  name = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


# ============================================================
# DATA SOURCES
# ============================================================

data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}


# ============================================================
# 1. NETWORKING
# ============================================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = local.name
  cidr = var.vpc_cidr

  azs = [
    "${var.aws_region}a",
    "${var.aws_region}b"
  ]

  public_subnets = [
    "10.50.101.0/24",
    "10.50.102.0/24"
  ]

  private_subnets = [
    "10.50.1.0/24",
    "10.50.2.0/24"
  ]

  enable_nat_gateway   = var.create_nat_gateway
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = local.common_tags
}


# ============================================================
# 2. JENKINS IAM ROLE
# ============================================================

resource "aws_iam_role" "jenkins" {
  name = "${local.name}-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}


# ============================================================
# JENKINS ECR PERMISSIONS
# ============================================================

resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}


# ============================================================
# JENKINS EKS PERMISSIONS
# ============================================================

resource "aws_iam_role_policy_attachment" "jenkins_eks" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


# ============================================================
# JENKINS S3 PERMISSIONS
# ============================================================

resource "aws_iam_role_policy_attachment" "jenkins_s3" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}


# ============================================================
# JENKINS TERRAFORM LAB PERMISSIONS
# ============================================================
# Existing configuration retained.
# For hardened enterprise production, replace PowerUserAccess
# with a dedicated least-privilege Terraform execution role.

resource "aws_iam_role_policy_attachment" "jenkins_terraform_lab" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}


# ============================================================
# JENKINS SSM PERMISSIONS
# ============================================================

resource "aws_iam_role_policy_attachment" "jenkins_ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# ============================================================
# IMPORTANT:
# TERRAFORM IAM READ PERMISSIONS
# ============================================================
# Required because terraform-aws-modules/eks uses IAM
# resources/data during plan/apply.
#
# Includes permissions required to:
# - Read Jenkins inline role policies
# - Read EKS OIDC provider
# - Read IAM policies used by EKS encryption
# ============================================================

resource "aws_iam_role_policy" "jenkins_terraform_iam_read" {
  name = "${local.name}-jenkins-terraform-iam-read"
  role = aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:GetInstanceProfile",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:GetOpenIDConnectProvider",
          "iam:GetPolicy"
        ]

        Resource = "*"
      }
    ]
  })
}


# ============================================================
# 3. JENKINS INSTANCE PROFILE
# ============================================================

resource "aws_iam_instance_profile" "jenkins" {
  name = "${local.name}-jenkins-profile"
  role = aws_iam_role.jenkins.name
}


# ============================================================
# 4. JENKINS SECURITY GROUP
# ============================================================

resource "aws_security_group" "jenkins" {
  name        = "${local.name}-jenkins-sg"
  description = "Jenkins CI/CD controller"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Jenkins UI / GitLab webhook"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"

    cidr_blocks = [
      var.jenkins_allowed_cidr
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}


# ============================================================
# 5. SONARQUBE IAM
# ============================================================

resource "aws_iam_role" "sonarqube" {
  name = "${local.name}-sonarqube-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}


resource "aws_iam_role_policy_attachment" "sonarqube_ssm" {
  role       = aws_iam_role.sonarqube.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


resource "aws_iam_instance_profile" "sonarqube" {
  name = "${local.name}-sonarqube-profile"
  role = aws_iam_role.sonarqube.name
}


# ============================================================
# 6. SONARQUBE SECURITY GROUP
# ============================================================

resource "aws_security_group" "sonarqube" {
  name        = "${local.name}-sonarqube-sg"
  description = "SonarQube server"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "SonarQube from Jenkins"
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins.id]
  }

  ingress {
    description = "SonarQube administration"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"

    cidr_blocks = [
      var.sonarqube_admin_cidr
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}


# ============================================================
# 7. JENKINS EC2
# ============================================================

resource "aws_instance" "jenkins" {
  ami                         = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type               = var.jenkins_instance_type
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name
  associate_public_ip_address = true

  user_data = file("${path.module}/user-data/jenkins-bootstrap.sh")

  tags = merge(local.common_tags, {
    Name = "${local.name}-jenkins"
    Role = "jenkins"
  })

  depends_on = [
    module.vpc
  ]
}


# ============================================================
# 8. SONARQUBE EC2
# ============================================================

resource "aws_instance" "sonarqube" {
  ami                         = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type               = var.sonarqube_instance_type
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.sonarqube.id]
  iam_instance_profile        = aws_iam_instance_profile.sonarqube.name
  associate_public_ip_address = true

  user_data = file("${path.module}/user-data/sonarqube-bootstrap.sh")

  tags = merge(local.common_tags, {
    Name = "${local.name}-sonarqube"
    Role = "sonarqube"
  })

  depends_on = [
    module.vpc
  ]
}


# ============================================================
# 9. ECR
# ============================================================

resource "aws_ecr_repository" "app" {
  name                 = local.name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}


resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1

        description = "Keep the newest 30 images"

        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }

        action = {
          type = "expire"
        }
      }
    ]
  })
}


# ============================================================
# 10. S3 MEDIA BUCKET
# ============================================================

resource "aws_s3_bucket" "media" {
  bucket = "${local.name}-media-${data.aws_caller_identity.current.account_id}"

  tags = local.common_tags
}


resource "aws_s3_bucket_versioning" "media" {
  bucket = aws_s3_bucket.media.id

  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_public_access_block" "media" {
  bucket = aws_s3_bucket.media.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


# ============================================================
# 11. PRIVATE DATA SECURITY GROUP
# ============================================================

resource "aws_security_group" "data" {
  name        = "${local.name}-data-sg"
  description = "Private PostgreSQL and Redis access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"

    cidr_blocks = [
      var.vpc_cidr
    ]
  }

  ingress {
    description = "Redis from VPC"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"

    cidr_blocks = [
      var.vpc_cidr
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}


# ============================================================
# 12. RDS POSTGRESQL
# ============================================================

resource "aws_db_subnet_group" "postgres" {
  name       = "${local.name}-postgres"
  subnet_ids = module.vpc.private_subnets

  tags = local.common_tags
}


resource "aws_db_instance" "postgres" {
  identifier = local.name

  engine         = "postgres"
  engine_version = "17"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  port = 5432

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.data.id]

  publicly_accessible = false

  multi_az = true

  storage_encrypted = true

  backup_retention_period = 7

  deletion_protection = true

  skip_final_snapshot = false

  tags = local.common_tags
}


# ============================================================
# 13. ELASTICACHE REDIS
# ============================================================

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.name}-redis"
  subnet_ids = module.vpc.private_subnets
}


resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${local.name}-redis"

  description = "Kailash E-Store Redis cache"

  engine    = "redis"
  node_type = var.redis_node_type

  num_cache_clusters = 2

  port = 6379

  subnet_group_name = aws_elasticache_subnet_group.redis.name

  security_group_ids = [
    aws_security_group.data.id
  ]

  automatic_failover_enabled = true
  multi_az_enabled           = true

  tags = local.common_tags
}


# ============================================================
# 14. AMAZON EKS
# ============================================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.name
  kubernetes_version = var.eks_kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  # ----------------------------------------------------------
  # JENKINS EKS ACCESS
  # ----------------------------------------------------------

  access_entries = {
    jenkins = {
      principal_arn = aws_iam_role.jenkins.arn

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # ----------------------------------------------------------
  # MANAGED NODE GROUP
  # ----------------------------------------------------------

  eks_managed_node_groups = {
    default = {
      instance_types = [
        var.eks_node_instance_type
      ]

      min_size     = 2
      max_size     = 6
      desired_size = 2
    }
  }

  tags = local.common_tags
}


# ============================================================
# 15. OUTPUTS
# ============================================================
# These outputs are consumed by Jenkins and Ansible.

output "jenkins_instance_id" {
  value = aws_instance.jenkins.id
}


output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
}


output "jenkins_url" {
  value = "http://${aws_instance.jenkins.public_ip}:8080"
}


output "sonarqube_instance_id" {
  value = aws_instance.sonarqube.id
}


output "sonarqube_public_ip" {
  value = aws_instance.sonarqube.public_ip
}


output "sonarqube_url" {
  value = "http://${aws_instance.sonarqube.public_ip}:9000"
}


output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}


output "eks_cluster_name" {
  value = module.eks.cluster_name
}


output "media_bucket" {
  value = aws_s3_bucket.media.bucket
}


output "rds_endpoint" {
  value     = aws_db_instance.postgres.address
  sensitive = true
}


output "redis_endpoint" {
  value     = aws_elasticache_replication_group.redis.primary_endpoint_address
  sensitive = true
}