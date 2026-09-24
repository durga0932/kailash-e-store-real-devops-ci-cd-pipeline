pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
    }

    parameters {
        booleanParam(
            name: 'APPLY_INFRA',
            defaultValue: true,
            description: 'Run Terraform plan + apply before the application release. For production, use a separate controlled infrastructure pipeline.'
        )
    }

    environment {
        AWS_REGION = 'ap-south-1'
        PROJECT = 'kailash-e-store'
        ECR_REPOSITORY = 'kailash-e-store-prod'
        EKS_CLUSTER = 'kailash-e-store-prod'
        IMAGE_TAG = "${BUILD_NUMBER}"
        DOCKERHUB_USERNAME = 'shivsoftapp'
        DOCKERHUB_REPOSITORY = 'kailash-e-store'
        GITLAB_REPOSITORY = 'https://gitlab.com/SOFTAPP-TECHNOLOGIES/kailash-e-store-real-devops-ci-cd-pipeline.git'
    }

    stages {

        stage('1. Checkout') {
            steps {
                checkout scm
            }
        }

        stage('2. Terraform Infrastructure') {
            steps {
                dir('terraform') {
                    withCredentials([string(credentialsId: 'rds-db-password', variable: 'TF_VAR_db_password')]) {
                        sh '''
                            set -e
                            terraform init -input=false
                            terraform validate
                            terraform plan -input=false -out=tfplan

                            if [ "${APPLY_INFRA}" = "true" ]; then
                              terraform apply -input=false -auto-approve tfplan
                            fi
                        '''
                    }
                }
            }
        }

        stage('3. Generate Ansible Inventory') {
            steps {
                dir('terraform') {
                    sh '''
                        terraform output -raw jenkins_instance_id > /tmp/jenkins_id
                        terraform output -raw sonarqube_instance_id > /tmp/sonarqube_id
                    '''
                }

                sh '''
                    set -e
                    JENKINS_ID=$(cat /tmp/jenkins_id)
                    SONAR_ID=$(cat /tmp/sonarqube_id)

                    cat > ansible/inventory.ini <<EOF_INVENTORY
[jenkins]
jenkins-host ansible_host=${JENKINS_ID}

[sonarqube]
sonarqube-host ansible_host=${SONAR_ID}

[all:vars]
ansible_connection=amazon.aws.aws_ssm
ansible_aws_ssm_region=${AWS_REGION}
ansible_python_interpreter=/usr/bin/python3
EOF_INVENTORY
                '''
            }
        }

        stage('4. Ansible Configuration') {
            steps {
                sh '''
                    set -e
                    ansible-galaxy collection install -r ansible/requirements.yml
                    ansible-playbook -i ansible/inventory.ini ansible/site.yml
                '''
            }
        }

        stage('5. Install & Test') {
            steps {
                sh '''
                    set -e
                    python3 -m venv .ci-venv
                    . .ci-venv/bin/activate
                    python -m pip install --upgrade pip
                    pip install -r requirements.txt
                    python manage.py check
                    python manage.py test
                '''
            }
        }

        stage('6. SonarQube Analysis') {
            steps {
                script {
                    env.SONAR_HOST_URL = sh(
                        script: 'cd terraform && terraform output -raw sonarqube_url',
                        returnStdout: true
                    ).trim()
                }

                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                    sh '''
                        set -e
                        sonar-scanner \
                          -Dsonar.host.url="${SONAR_HOST_URL}" \
                          -Dsonar.token="${SONAR_TOKEN}"
                    '''
                }
            }
        }

        stage('7. Trivy Filesystem Scan') {
            steps {
                sh 'trivy fs --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed .'
            }
        }

        stage('8. Docker Build') {
            steps {
                sh '''
                    set -e
                    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
                    IMAGE_URI=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}
                    docker build -t ${IMAGE_URI} .
                '''
            }
        }

        stage('9. Trivy Image Scan') {
            steps {
                sh '''
                    set -e
                    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
                    IMAGE_URI=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}
                    trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed ${IMAGE_URI}
                '''
            }
        }

        stage('10. Push Image - ECR + Docker Hub Mirror') {
            steps {
                sh '''
                    set -e
                    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
                    ECR_HOST=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                    ECR_IMAGE=${ECR_HOST}/${ECR_REPOSITORY}:${IMAGE_TAG}

                    aws ecr get-login-password --region ${AWS_REGION} | \
                      docker login --username AWS --password-stdin ${ECR_HOST}

                    docker push ${ECR_IMAGE}
                '''

                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        set -e
                        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
                        ECR_IMAGE=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}

                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker tag ${ECR_IMAGE} ${DOCKERHUB_USERNAME}/${DOCKERHUB_REPOSITORY}:${IMAGE_TAG}
                        docker push ${DOCKERHUB_USERNAME}/${DOCKERHUB_REPOSITORY}:${IMAGE_TAG}
                        docker tag ${ECR_IMAGE} ${DOCKERHUB_USERNAME}/${DOCKERHUB_REPOSITORY}:latest
                        docker push ${DOCKERHUB_USERNAME}/${DOCKERHUB_REPOSITORY}:latest
                        docker logout
                    '''
                }
            }
        }

        stage('11. Helm Deploy to EKS') {
            steps {
                sh '''
                    set -e
                    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

                    aws eks update-kubeconfig \
                      --region ${AWS_REGION} \
                      --name ${EKS_CLUSTER}

                    helm lint helm/kailash-e-store

                    helm upgrade --install kailash-e-store ./helm/kailash-e-store \
                      --set image.repository=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY} \
                      --set image.tag=${IMAGE_TAG} \
                      --wait \
                      --timeout 10m
                '''
            }
        }

        stage('12. EKS Verification') {
            steps {
                sh '''
                    set -e
                    kubectl get nodes
                    kubectl get pods -A
                    kubectl get svc
                    kubectl get hpa
                    kubectl rollout status deployment/kailash-e-store-kailash-e-store --timeout=300s
                '''
            }
        }

        stage('13. Production Health Check') {
            steps {
                sh '''
                    set -e
                    kubectl get endpoints
                    kubectl get pods -l app=kailash-e-store
                '''
            }
        }

        stage('14. Monitoring Stack') {
            steps {
                sh '''
                    set -e
                    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
                    helm repo update

                    kubectl create namespace monitoring \
                      --dry-run=client -o yaml | kubectl apply -f -

                    helm upgrade --install monitoring \
                      prometheus-community/kube-prometheus-stack \
                      --namespace monitoring \
                      -f monitoring/kube-prometheus-stack-values.yaml \
                      --wait \
                      --timeout 10m

                    kubectl get pods -n monitoring
                '''
            }
        }
    }

    post {
        success {
            echo 'Kailash E-Store: fully automated AWS DevSecOps pipeline completed.'
        }
        failure {
            echo 'Pipeline failed. Check the failed stage and Jenkins console output.'
        }
        always {
            echo "Build number: ${BUILD_NUMBER}"
            echo "GitLab repository: ${GITLAB_REPOSITORY}"
        }
    }
}
