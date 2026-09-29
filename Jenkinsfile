pipeline {

    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 60, unit: 'MINUTES')
    }


    // =========================================================
    // PARAMETERS
    // =========================================================

    parameters {

        booleanParam(
            name: 'APPLY_INFRA',
            defaultValue: false,
            description: 'Enable only when Terraform infrastructure changes should be applied.'
        )
    }


    // =========================================================
    // ENVIRONMENT
    // =========================================================

    environment {

        AWS_REGION = 'ap-south-1'

        PROJECT = 'kailash-e-store'

        ECR_REPOSITORY = 'kailash-e-store-prod'

        EKS_CLUSTER = 'kailash-e-store-prod'

        DOCKERHUB_REPOSITORY = 'kailash-e-store'

        IMAGE_TAG = "${BUILD_NUMBER}"

        GITLAB_REPOSITORY =
            'https://gitlab.com/SOFTAPP-TECHNOLOGIES/kailash-e-store-real-devops-ci-cd-pipeline.git'

        TF_IN_AUTOMATION = 'true'

        TF_INPUT = 'false'

        AWS_PAGER = ''
    }


    // =========================================================
    // STAGES
    // =========================================================

    stages {


        // =====================================================
        // 1. CHECKOUT
        // =====================================================

        stage('1. Checkout Source Code') {

            steps {

                checkout scm

                sh '''
                    set -e

                    echo "======================================"
                    echo " CHECKOUT SOURCE CODE"
                    echo "======================================"

                    git rev-parse --short HEAD

                    echo "Repository:"
                    echo "${GITLAB_REPOSITORY}"

                    echo "Build:"
                    echo "${BUILD_NUMBER}"
                '''
            }
        }


        // =====================================================
        // 2. TERRAFORM
        // =====================================================

        stage('2. Terraform Infrastructure') {

            steps {

                dir('terraform') {

                    withCredentials([
                        string(
                            credentialsId: 'rds-db-password',
                            variable: 'TF_VAR_db_password'
                        )
                    ]) {

                        sh '''
                            set -e

                            echo "======================================"
                            echo " TERRAFORM INIT"
                            echo "======================================"

                            terraform init \
                              -input=false \
                              -reconfigure


                            echo "======================================"
                            echo " TERRAFORM VALIDATE"
                            echo "======================================"

                            terraform validate


                            echo "======================================"
                            echo " TERRAFORM STATE"
                            echo "======================================"

                            terraform state list


                            echo "======================================"
                            echo " TERRAFORM OUTPUTS"
                            echo "======================================"

                            terraform output


                            echo "======================================"
                            echo " TERRAFORM PLAN"
                            echo "======================================"

                            terraform plan \
                              -input=false \
                              -out=tfplan


                            if [ "${APPLY_INFRA}" = "true" ]; then

                                echo "======================================"
                                echo " TERRAFORM APPLY"
                                echo "======================================"

                                terraform apply \
                                  -input=false \
                                  -auto-approve \
                                  tfplan

                            else

                                echo "======================================"
                                echo " APPLY_INFRA = FALSE"
                                echo " Terraform Apply Skipped"
                                echo "======================================"

                            fi
                        '''
                    }
                }
            }
        }


        // =====================================================
        // 3. EC2 DETECTION
        // =====================================================

        stage('3. EC2 Detect & SSM Validation') {

            steps {

                dir('terraform') {

                    sh '''
                        set -e

                        echo "======================================"
                        echo " EC2 INSTANCE DETECTION"
                        echo "======================================"


                        JENKINS_ID=$(terraform output -raw jenkins_instance_id)

                        SONAR_ID=$(terraform output -raw sonarqube_instance_id)


                        test -n "${JENKINS_ID}"

                        test -n "${SONAR_ID}"


                        echo "Jenkins Instance : ${JENKINS_ID}"

                        echo "SonarQube Instance : ${SONAR_ID}"


                        echo "======================================"
                        echo " JENKINS EC2"
                        echo "======================================"


                        JENKINS_INFO=$(aws ec2 describe-instances \
                          --region "${AWS_REGION}" \
                          --instance-ids "${JENKINS_ID}" \
                          --query 'Reservations[0].Instances[0].[PrivateIpAddress,PublicIpAddress,State.Name]' \
                          --output text)


                        echo "${JENKINS_INFO}"


                        echo "======================================"
                        echo " SONARQUBE EC2"
                        echo "======================================"


                        SONAR_INFO=$(aws ec2 describe-instances \
                          --region "${AWS_REGION}" \
                          --instance-ids "${SONAR_ID}" \
                          --query 'Reservations[0].Instances[0].[PrivateIpAddress,PublicIpAddress,State.Name]' \
                          --output text)


                        echo "${SONAR_INFO}"


                        JENKINS_PRIVATE_IP=$(echo "${JENKINS_INFO}" | awk '{print $1}')

                        JENKINS_PUBLIC_IP=$(echo "${JENKINS_INFO}" | awk '{print $2}')

                        JENKINS_STATE=$(echo "${JENKINS_INFO}" | awk '{print $3}')


                        SONARQUBE_PRIVATE_IP=$(echo "${SONAR_INFO}" | awk '{print $1}')

                        SONARQUBE_PUBLIC_IP=$(echo "${SONAR_INFO}" | awk '{print $2}')

                        SONARQUBE_STATE=$(echo "${SONAR_INFO}" | awk '{print $3}')


                        test "${JENKINS_STATE}" = "running"

                        test "${SONARQUBE_STATE}" = "running"


                        echo "======================================"
                        echo " SSM VALIDATION"
                        echo "======================================"


                        JENKINS_SSM_COUNT=$(aws ssm describe-instance-information \
                          --region "${AWS_REGION}" \
                          --filters "Key=InstanceIds,Values=${JENKINS_ID}" \
                          --query 'length(InstanceInformationList)' \
                          --output text)


                        SONAR_SSM_COUNT=$(aws ssm describe-instance-information \
                          --region "${AWS_REGION}" \
                          --filters "Key=InstanceIds,Values=${SONAR_ID}" \
                          --query 'length(InstanceInformationList)' \
                          --output text)


                        echo "Jenkins SSM: ${JENKINS_SSM_COUNT}"

                        echo "SonarQube SSM: ${SONAR_SSM_COUNT}"


                        test "${JENKINS_SSM_COUNT}" -ge 1

                        test "${SONAR_SSM_COUNT}" -ge 1


                        cat > ../ec2-details.env <<EOF_EC2
JENKINS_INSTANCE_ID=${JENKINS_ID}
JENKINS_PRIVATE_IP=${JENKINS_PRIVATE_IP}
JENKINS_PUBLIC_IP=${JENKINS_PUBLIC_IP}

SONARQUBE_INSTANCE_ID=${SONAR_ID}
SONARQUBE_PRIVATE_IP=${SONARQUBE_PRIVATE_IP}
SONARQUBE_PUBLIC_IP=${SONARQUBE_PUBLIC_IP}
EOF_EC2
                    '''
                }


                sh '''
                    set -e

                    echo "======================================"
                    echo " EC2 INFORMATION"
                    echo "======================================"

                    cat ec2-details.env
                '''
            }
        }


        // =====================================================
        // 4. ANSIBLE
        // =====================================================

        stage('4. Ansible Configuration') {

            steps {

                sh '''
                    set -e

                    echo "======================================"
                    echo " ANSIBLE COLLECTIONS"
                    echo "======================================"

                    /opt/ansible-venv/bin/ansible-galaxy collection install \
                    -r ansible/requirements.yml \
                    --force

                    echo "======================================"
                    echo " ANSIBLE INVENTORY"
                    echo "======================================"

                    . ./ec2-details.env

                    cat > ansible/inventory.ini <<EOF_INVENTORY
        [jenkins]
        jenkins-host ansible_host=${JENKINS_INSTANCE_ID}

        [sonarqube]
        sonarqube-host ansible_host=${SONARQUBE_INSTANCE_ID}

        [all:vars]
        ansible_connection=amazon.aws.aws_ssm
        ansible_aws_ssm_region=${AWS_REGION}
        ansible_aws_ssm_bucket_name=kailash-e-store-prod-tfstate-518056141688
        ansible_python_interpreter=/usr/bin/python3
        EOF_INVENTORY

                    cat ansible/inventory.ini

                    echo "======================================"
                    echo " ANSIBLE PLAYBOOK"
                    echo "======================================"

                    /opt/ansible-venv/bin/ansible-playbook \
                    -i ansible/inventory.ini \
                    ansible/playbook.yml
                '''
            }
        }


        // =====================================================
        // 5. DJANGO VALIDATION
        // =====================================================

        stage('5. Django Project Validation') {

            steps {

                sh '''
                    set -e

                    echo "======================================"
                    echo " DJANGO VALIDATION"
                    echo "======================================"


                    python3 -m venv .ci-venv

                    . .ci-venv/bin/activate


                    python -m pip install --upgrade pip


                    pip install -r requirements.txt


                    echo "===== DJANGO CHECK ====="

                    python manage.py check


                    echo "===== DJANGO TEST ====="

                    python manage.py test


                    echo "===== MIGRATION CHECK ====="

                    python manage.py makemigrations \
                      --check \
                      --dry-run
                '''
            }
        }


        // =====================================================
        // 6. SONARQUBE
        // =====================================================

        stage('6. SonarQube Code Analysis') {

            steps {

                script {

                    env.SONAR_HOST_URL = sh(
                        script: '''
                            cd terraform

                            terraform output \
                              -raw sonarqube_url \
                              2>/dev/null || true
                        ''',
                        returnStdout: true
                    ).trim()


                    if (!env.SONAR_HOST_URL) {

                        sh '''
                            . ./ec2-details.env

                            test -n "${SONARQUBE_PRIVATE_IP}"
                        '''


                        env.SONAR_HOST_URL = sh(
                            script: '''
                                . ./ec2-details.env

                                echo "http://${SONARQUBE_PRIVATE_IP}:9000"
                            ''',
                            returnStdout: true
                        ).trim()
                    }


                    echo "SonarQube: ${env.SONAR_HOST_URL}"
                }


                withCredentials([
                    string(
                        credentialsId: 'sonar-token',
                        variable: 'SONAR_TOKEN'
                    )
                ]) {

                    sh '''
                        set -e

                        echo "======================================"
                        echo " SONARQUBE ANALYSIS"
                        echo "======================================"


                        sonar-scanner \
                          -Dsonar.host.url="${SONAR_HOST_URL}" \
                          -Dsonar.token="${SONAR_TOKEN}"
                    '''
                }
            }
        }


        // =====================================================
        // 7. TRIVY FILESYSTEM
        // =====================================================

        stage('7. Trivy Filesystem Scan') {

            steps {

                sh '''
                    set -e

                    echo "======================================"
                    echo " TRIVY FILESYSTEM SCAN"
                    echo "======================================"


                    trivy fs \
                      --exit-code 1 \
                      --severity HIGH,CRITICAL \
                      --ignore-unfixed \
                      .
                '''
            }
        }


        // =====================================================
        // 8. DOCKER BUILD
        // =====================================================

        stage('8. Docker Build') {

            steps {

                sh '''
                    set -e


                    ACCOUNT_ID=$(aws sts get-caller-identity \
                      --query Account \
                      --output text)


                    ECR_IMAGE="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"


                    echo "======================================"
                    echo " DOCKER BUILD"
                    echo "======================================"

                    echo "Image: ${ECR_IMAGE}"


                    docker build \
                      --pull \
                      -t "${ECR_IMAGE}" \
                      .


                    docker image inspect "${ECR_IMAGE}" >/dev/null
                '''
            }
        }


        // =====================================================
        // 9. TRIVY IMAGE
        // =====================================================

        stage('9. Trivy Docker Image Scan') {

            steps {

                sh '''
                    set -e


                    ACCOUNT_ID=$(aws sts get-caller-identity \
                      --query Account \
                      --output text)


                    ECR_IMAGE="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"


                    echo "======================================"
                    echo " TRIVY IMAGE SCAN"
                    echo "======================================"


                    trivy image \
                      --exit-code 1 \
                      --severity HIGH,CRITICAL \
                      --ignore-unfixed \
                      "${ECR_IMAGE}"
                '''
            }
        }


        // =====================================================
        // 10. PUSH ECR + DOCKER HUB
        // =====================================================

        stage('10. Push Docker Image') {

            steps {

                sh '''
                    set -e


                    ACCOUNT_ID=$(aws sts get-caller-identity \
                      --query Account \
                      --output text)


                    ECR_HOST="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

                    ECR_IMAGE="${ECR_HOST}/${ECR_REPOSITORY}:${IMAGE_TAG}"


                    echo "======================================"
                    echo " ECR LOGIN"
                    echo "======================================"


                    aws ecr get-login-password \
                      --region "${AWS_REGION}" | \
                      docker login \
                      --username AWS \
                      --password-stdin "${ECR_HOST}"


                    echo "======================================"
                    echo " PUSH ECR"
                    echo "======================================"


                    docker push "${ECR_IMAGE}"
                '''


                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {

                    sh '''
                        set -e


                        ACCOUNT_ID=$(aws sts get-caller-identity \
                          --query Account \
                          --output text)


                        ECR_HOST="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

                        ECR_IMAGE="${ECR_HOST}/${ECR_REPOSITORY}:${IMAGE_TAG}"


                        echo "======================================"
                        echo " DOCKER HUB LOGIN"
                        echo "======================================"


                        echo "${DOCKER_PASS}" | \
                          docker login \
                          --username "${DOCKER_USER}" \
                          --password-stdin


                        echo "======================================"
                        echo " DOCKER HUB PUSH"
                        echo "======================================"


                        docker tag \
                          "${ECR_IMAGE}" \
                          "${DOCKER_USER}/${DOCKERHUB_REPOSITORY}:${IMAGE_TAG}"


                        docker push \
                          "${DOCKER_USER}/${DOCKERHUB_REPOSITORY}:${IMAGE_TAG}"


                        docker tag \
                          "${ECR_IMAGE}" \
                          "${DOCKER_USER}/${DOCKERHUB_REPOSITORY}:latest"


                        docker push \
                          "${DOCKER_USER}/${DOCKERHUB_REPOSITORY}:latest"


                        docker logout
                    '''
                }
            }
        }


        // =====================================================
        // 11. EKS + HELM DEPLOY
        // =====================================================

        stage('11. Helm Deploy to EKS') {

            steps {

                sh '''
                    set -e


                    ACCOUNT_ID=$(aws sts get-caller-identity \
                      --query Account \
                      --output text)


                    ECR_IMAGE="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}"


                    echo "======================================"
                    echo " UPDATE EKS KUBECONFIG"
                    echo "======================================"


                    aws eks update-kubeconfig \
                      --region "${AWS_REGION}" \
                      --name "${EKS_CLUSTER}"


                    kubectl config current-context


                    echo "======================================"
                    echo " HELM LINT"
                    echo "======================================"


                    helm lint helm/kailash-e-store


                    echo "======================================"
                    echo " HELM TEMPLATE"
                    echo "======================================"


                    helm template \
                      kailash-e-store \
                      ./helm/kailash-e-store \
                      --set image.repository="${ECR_IMAGE}" \
                      --set image.tag="${IMAGE_TAG}" \
                      > /tmp/kailash-e-store-rendered.yaml


                    echo "======================================"
                    echo " HELM DEPLOY"
                    echo "======================================"


                    helm upgrade --install \
                      kailash-e-store \
                      ./helm/kailash-e-store \
                      --set image.repository="${ECR_IMAGE}" \
                      --set image.tag="${IMAGE_TAG}" \
                      --wait \
                      --timeout 10m


                    helm status kailash-e-store
                '''
            }
        }


        // =====================================================
        // 12. KUBERNETES VERIFICATION
        // =====================================================

        stage('12. Verify Kubernetes Deployment') {

            steps {

                sh '''
                    set -e


                    echo "======================================"
                    echo " KUBERNETES NODES"
                    echo "======================================"


                    kubectl get nodes


                    echo "======================================"
                    echo " PODS"
                    echo "======================================"


                    kubectl get pods -A


                    echo "======================================"
                    echo " SERVICES"
                    echo "======================================"


                    kubectl get svc


                    echo "======================================"
                    echo " HPA"
                    echo "======================================"


                    kubectl get hpa
                '''
            }
        }


        // =====================================================
        // 13. ROLLOUT STATUS
        // =====================================================

        stage('13. Rollout Status Check') {

            steps {

                sh '''
                    set -e


                    echo "======================================"
                    echo " ROLLOUT STATUS"
                    echo "======================================"


                    kubectl rollout status \
                      deployment/kailash-e-store-kailash-e-store \
                      --timeout=300s
                '''
            }
        }


        // =====================================================
        // 14. APPLICATION HEALTH
        // =====================================================

        stage('14. Application Health Check') {

            steps {

                sh '''
                    set -e


                    echo "======================================"
                    echo " APPLICATION SERVICE"
                    echo "======================================"


                    kubectl get svc \
                      kailash-e-store-kailash-e-store \
                      -o wide


                    SERVICE_IP=$(kubectl get svc \
                      kailash-e-store-kailash-e-store \
                      -o jsonpath='{.status.loadBalancer.ingress[0].ip}' \
                      2>/dev/null || true)


                    SERVICE_HOSTNAME=$(kubectl get svc \
                      kailash-e-store-kailash-e-store \
                      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
                      2>/dev/null || true)


                    if [ -n "${SERVICE_IP}" ]; then

                        echo "LoadBalancer IP: ${SERVICE_IP}"

                        curl -fsS \
                          --max-time 20 \
                          "http://${SERVICE_IP}/" \
                          >/dev/null


                    elif [ -n "${SERVICE_HOSTNAME}" ]; then

                        echo "LoadBalancer Hostname: ${SERVICE_HOSTNAME}"

                        curl -fsS \
                          --max-time 20 \
                          "http://${SERVICE_HOSTNAME}/" \
                          >/dev/null


                    else

                        echo "LoadBalancer address not available."

                        kubectl describe svc \
                          kailash-e-store-kailash-e-store

                        exit 1

                    fi


                    echo "Application health check successful."
                '''
            }
        }


        // =====================================================
        // 15. PROMETHEUS / GRAFANA
        // =====================================================

        stage('15. Monitoring Verification') {

            steps {

                sh '''
                    set -e


                    echo "======================================"
                    echo " MONITORING"
                    echo "======================================"


                    kubectl get pods \
                      -n monitoring


                    kubectl get svc \
                      -n monitoring


                    echo "======================================"
                    echo " PROMETHEUS / GRAFANA SERVICES"
                    echo "======================================"


                    kubectl get svc \
                      -n monitoring \
                      | grep -E "prometheus|grafana" || true
                '''
            }
        }
    }


    // =========================================================
    // POST ACTIONS
    // =========================================================

    post {

        success {

            echo '''
=========================================================
 KAILASH E-STORE DEVSECOPS PIPELINE SUCCESS
=========================================================

GitLab
   ↓
Terraform
   ↓
S3 Remote State
   ↓
Ansible / AWS SSM
   ↓
Django Validation
   ↓
SonarQube
   ↓
Trivy
   ↓
Docker
   ↓
ECR
   ↓
Docker Hub
   ↓
Helm
   ↓
EKS
   ↓
Health Check
   ↓
Monitoring

=========================================================
'''
        }


        failure {

            echo '''
=========================================================
 KAILASH E-STORE PIPELINE FAILED
=========================================================

Check the failed stage and Jenkins Console Output.

=========================================================
'''
        }


        aborted {

            echo '''
=========================================================
 KAILASH E-STORE PIPELINE ABORTED
=========================================================

The Jenkins build was aborted before completion.

=========================================================
'''
        }


        always {

            echo "======================================"

            echo " BUILD INFORMATION"

            echo "======================================"

            echo "Build Number : ${env.BUILD_NUMBER}"

            echo "Build Result : ${currentBuild.currentResult}"
        }
    }
}