pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 60, unit: 'MINUTES')
    }

    parameters {
        booleanParam(
            name: 'APPLY_INFRA',
            defaultValue: false,
            description: 'Run Terraform apply. Keep unchecked for plan-only execution.'
        )
    }

    environment {
        AWS_REGION = 'ap-south-1'

        PROJECT = 'kailash-e-store'

        ECR_REPOSITORY = 'kailash-e-store-prod'

        EKS_CLUSTER = 'kailash-e-store-prod'

        IMAGE_TAG = "${BUILD_NUMBER}"

        DOCKERHUB_REPOSITORY = 'kailash-e-store'

        GITLAB_REPOSITORY =
            'https://gitlab.com/SOFTAPP-TECHNOLOGIES/kailash-e-store-real-devops-ci-cd-pipeline.git'

        AWS_PAGER = ''

        TF_IN_AUTOMATION = 'true'

        TF_INPUT = 'false'
    }


    stages {

        // =========================================================
        // 1. CHECKOUT
        // =========================================================

        stage('1. Checkout') {
            steps {

                checkout scm

                sh '''
                    set -e

                    echo "======================================"
                    echo " GIT / WORKSPACE"
                    echo "======================================"

                    git rev-parse --short HEAD

                    git branch --show-current || true

                    echo "Repository: ${GITLAB_REPOSITORY}"

                    echo "Build: ${BUILD_NUMBER}"
                '''
            }
        }


        // =========================================================
        // 2. TERRAFORM INFRASTRUCTURE
        // =========================================================

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
                                echo " TERRAFORM APPLY ENABLED"
                                echo "======================================"

                                terraform apply \
                                  -input=false \
                                  -auto-approve \
                                  tfplan

                            else

                                echo "======================================"
                                echo " TERRAFORM APPLY SKIPPED"
                                echo "======================================"

                                echo "APPLY_INFRA is false."
                                echo "Only Terraform plan was executed."

                            fi
                        '''
                    }
                }
            }
        }


        // =========================================================
        // 3. EC2 DETECTION + SSM INVENTORY
        // =========================================================

        stage('3. EC2 Detect & Generate Ansible Inventory') {

            steps {

                dir('terraform') {

                    sh '''
                        set -e

                        echo "======================================"
                        echo " EC2 INSTANCE AUTO DETECTION"
                        echo "======================================"


                        JENKINS_ID=$(terraform output -raw jenkins_instance_id)

                        SONAR_ID=$(terraform output -raw sonarqube_instance_id)


                        test -n "${JENKINS_ID}"

                        test -n "${SONAR_ID}"


                        echo "Jenkins Instance ID   : ${JENKINS_ID}"

                        echo "SonarQube Instance ID : ${SONAR_ID}"


                        echo "======================================"
                        echo " DETECT JENKINS EC2"
                        echo "======================================"


                        JENKINS_INFO=$(aws ec2 describe-instances \
                          --region "${AWS_REGION}" \
                          --instance-ids "${JENKINS_ID}" \
                          --query 'Reservations[0].Instances[0].[PrivateIpAddress,PublicIpAddress,State.Name]' \
                          --output text)


                        echo "======================================"
                        echo " DETECT SONARQUBE EC2"
                        echo "======================================"


                        SONAR_INFO=$(aws ec2 describe-instances \
                          --region "${AWS_REGION}" \
                          --instance-ids "${SONAR_ID}" \
                          --query 'Reservations[0].Instances[0].[PrivateIpAddress,PublicIpAddress,State.Name]' \
                          --output text)


                        JENKINS_PRIVATE_IP=$(echo "${JENKINS_INFO}" | awk '{print $1}')

                        JENKINS_PUBLIC_IP=$(echo "${JENKINS_INFO}" | awk '{print $2}')

                        JENKINS_STATE=$(echo "${JENKINS_INFO}" | awk '{print $3}')


                        SONARQUBE_PRIVATE_IP=$(echo "${SONAR_INFO}" | awk '{print $1}')

                        SONARQUBE_PUBLIC_IP=$(echo "${SONAR_INFO}" | awk '{print $2}')

                        SONARQUBE_STATE=$(echo "${SONAR_INFO}" | awk '{print $3}')


                        echo ""
                        echo "========== JENKINS =========="

                        echo "Instance ID : ${JENKINS_ID}"

                        echo "Private IP  : ${JENKINS_PRIVATE_IP}"

                        echo "Public IP   : ${JENKINS_PUBLIC_IP}"

                        echo "State       : ${JENKINS_STATE}"


                        echo ""
                        echo "========== SONARQUBE =========="

                        echo "Instance ID : ${SONAR_ID}"

                        echo "Private IP  : ${SONARQUBE_PRIVATE_IP}"

                        echo "Public IP   : ${SONARQUBE_PUBLIC_IP}"

                        echo "State       : ${SONARQUBE_STATE}"


                        test "${JENKINS_STATE}" = "running"

                        test "${SONARQUBE_STATE}" = "running"


                        echo ""
                        echo "======================================"
                        echo " AWS SSM VALIDATION"
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


                        echo "Jenkins SSM Managed    : ${JENKINS_SSM_COUNT}"

                        echo "SonarQube SSM Managed  : ${SONAR_SSM_COUNT}"


                        test "${JENKINS_SSM_COUNT}" -ge 1

                        test "${SONAR_SSM_COUNT}" -ge 1


                        echo ""
                        echo "======================================"
                        echo " EXPORT EC2 INFORMATION"
                        echo "======================================"


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
                    echo " GENERATE SSM INVENTORY"
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
ansible_python_interpreter=/usr/bin/python3
EOF_INVENTORY


                    echo ""
                    echo "===== GENERATED INVENTORY ====="

                    cat ansible/inventory.ini


                    echo ""
                    echo "===== EC2 DETAILS ====="

                    cat ec2-details.env
                '''
            }
        }


        // =========================================================
        // 4. ANSIBLE CONFIGURATION
        // =========================================================

        stage('4. Ansible Configuration') {

            steps {

                sh '''
                    set -e

                    echo "======================================"
                    echo " INSTALL ANSIBLE COLLECTIONS"
                    echo "======================================"


                    ansible-galaxy collection install \
                      -r ansible/requirements.yml \
                      --force


                    echo "======================================"
                    echo " INVENTORY VALIDATION"
                    echo "======================================"


                    ansible-inventory \
                      -i ansible/inventory.ini \
                      --graph


                    echo "======================================"
                    echo " ANSIBLE CONFIGURATION"
                    echo "======================================"


                    ansible-playbook \
                      -i ansible/inventory.ini \
                      ansible/playbook.yml
                '''
            }
        }


        // =========================================================
        // 5. APPLICATION TEST
        // =========================================================

        stage('5. Install & Test') {

            steps {

                sh '''
                    set -e


                    echo "======================================"
                    echo " PYTHON ENVIRONMENT"
                    echo "======================================"


                    python3 -m venv .ci-venv

                    . .ci-venv/bin/activate


                    python -m pip install --upgrade pip

                    pip install -r requirements.txt


                    echo "======================================"
                    echo " DJANGO CHECK"
                    echo "======================================"


                    python manage.py check


                    echo "======================================"
                    echo " DJANGO TESTS"
                    echo "======================================"


                    python manage.py test


                    echo "======================================"
                    echo " MIGRATION CHECK"
                    echo "======================================"


                    python manage.py makemigrations \
                      --check \
                      --dry-run
                '''
            }
        }


        // =========================================================
        // 6. SONARQUBE
        // =========================================================

        stage('6. SonarQube Analysis') {

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


                    echo "SonarQube URL: ${env.SONAR_HOST_URL}"
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


        // =========================================================
        // 7. TRIVY FILESYSTEM
        // =========================================================

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


        // =========================================================
        // 8. DOCKER BUILD
        // =========================================================

        stage('8. Docker Build') {

            steps {

                sh '''
                    set -e


                    ACCOUNT_ID=$(aws sts get-caller-identity \
                      --query Account \
                      --output text)


                    IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"


                    echo "======================================"
                    echo " DOCKER IMAGE"
                    echo "======================================"

                    echo "${IMAGE_URI}"


                    echo "======================================"
                    echo " DOCKER BUILD"
                    echo "======================================"


                    docker build \
                      --pull \
                      -t "${IMAGE_URI}" \
                      .


                    docker image inspect "${IMAGE_URI}" >/dev/null
                '''
            }
        }


        // =========================================================
        // 9. TRIVY IMAGE
        // =========================================================

        stage('9. Trivy Image Scan') {

            steps {

                sh '''
                    set -e


                    ACCOUNT_ID=$(aws sts get-caller-identity \
                      --query Account \
                      --output text)


                    IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"


                    echo "======================================"
                    echo " TRIVY IMAGE SCAN"
                    echo "======================================"


                    trivy image \
                      --exit-code 1 \
                      --severity HIGH,CRITICAL \
                      --ignore-unfixed \
                      "${IMAGE_URI}"
                '''
            }
        }


        // =========================================================
        // 10. ECR + DOCKER HUB
        // =========================================================

        stage('10. Push Image - ECR + Docker Hub Mirror') {

            steps {

                sh '''
                    set -e


                    ACCOUNT_ID=$(aws sts get-caller-identity \
                      --query Account \
                      --output text)


                    ECR_HOST="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

                    ECR_IMAGE="${ECR_HOST}/${ECR_REPOSITORY}:${IMAGE_TAG}"


                    echo "======================================"
                    echo " LOGIN TO ECR"
                    echo "======================================"


                    aws ecr get-login-password \
                      --region "${AWS_REGION}" | \
                      docker login \
                      --username AWS \
                      --password-stdin "${ECR_HOST}"


                    echo "======================================"
                    echo " PUSH TO ECR"
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


                        ECR_IMAGE="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"


                        echo "======================================"
                        echo " LOGIN TO DOCKER HUB"
                        echo "======================================"


                        echo "$DOCKER_PASS" | \
                          docker login \
                          --username "$DOCKER_USER" \
                          --password-stdin


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


        // =========================================================
        // 11. HELM -> EKS
        // =========================================================

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
                    echo " HELM TEMPLATE VALIDATION"
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


        // =========================================================
        // 12. EKS VERIFICATION
        // =========================================================

        stage('12. EKS Verification') {

            steps {

                sh '''
                    set -e


                    echo "======================================"
                    echo " EKS NODES"
                    echo "======================================"


                    kubectl get nodes


                    echo "======================================"
                    echo " ALL PODS"
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


                    echo "======================================"
                    echo " ROLLOUT"
                    echo "======================================"


                    kubectl rollout status \
                      deployment/kailash-e-store-kailash-e-store \
                      --timeout=300s


                    kubectl get deployment \
                      kailash-e-store-kailash-e-store
                '''
            }
        }


        // =========================================================
        // 13. PRODUCTION HEALTH CHECK
        // =========================================================

        stage('13. Production Health Check') {

            steps {

                sh '''
                    set -e


                    echo "======================================"
                    echo " ENDPOINTS"
                    echo "======================================"


                    kubectl get endpoints


                    echo "======================================"
                    echo " APPLICATION PODS"
                    echo "======================================"


                    kubectl get pods \
                      -l app=kailash-e-store \
                      -o wide


                    echo "======================================"
                    echo " SERVICE"
                    echo "======================================"


                    kubectl get svc \
                      kailash-e-store-kailash-e-store \
                      -o wide


                    echo "======================================"
                    echo " LOAD BALANCER HEALTH"
                    echo "======================================"


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

                        echo "LoadBalancer address is not available yet."


                        kubectl describe svc \
                          kailash-e-store-kailash-e-store


                        exit 1

                    fi


                    echo "Production health check completed successfully."
                '''
            }
        }


        // =========================================================
        // 14. MONITORING
        // =========================================================

        stage('14. Monitoring Stack') {

            steps {

                sh '''
                    set -e


                    echo "======================================"
                    echo " PROMETHEUS HELM REPOSITORY"
                    echo "======================================"


                    helm repo add prometheus-community \
                      https://prometheus-community.github.io/helm-charts \
                      || true


                    helm repo update


                    echo "======================================"
                    echo " MONITORING NAMESPACE"
                    echo "======================================"


                    kubectl create namespace monitoring \
                      --dry-run=client \
                      -o yaml | \
                      kubectl apply -f -


                    echo "======================================"
                    echo " KUBE PROMETHEUS STACK"
                    echo "======================================"


                    helm upgrade --install monitoring \
                      prometheus-community/kube-prometheus-stack \
                      --namespace monitoring \
                      -f monitoring/kube-prometheus-stack-values.yaml \
                      --wait \
                      --timeout 10m


                    echo "======================================"
                    echo " MONITORING PODS"
                    echo "======================================"


                    kubectl get pods \
                      -n monitoring


                    echo "======================================"
                    echo " MONITORING SERVICES"
                    echo "======================================"


                    kubectl get svc \
                      -n monitoring
                '''
            }
        }
    }


    // =============================================================
    // POST ACTIONS
    // =============================================================

    post {

        success {

            echo '''
=========================================================
 KAILASH E-STORE DEVSECOPS PIPELINE SUCCESS
=========================================================

GitLab
  -> Terraform
  -> S3 Remote State
  -> EC2 Auto Detection
  -> AWS SSM
  -> Ansible
  -> Django Tests
  -> SonarQube
  -> Trivy Filesystem
  -> Docker Build
  -> Trivy Image
  -> ECR
  -> Docker Hub
  -> Helm
  -> EKS
  -> Health Check
  -> Prometheus/Grafana

=========================================================
'''
        }


        failure {

            echo '''
=========================================================
 KAILASH E-STORE PIPELINE FAILED
=========================================================

Check the failed Jenkins stage and console output.

=========================================================
'''
        }


        always {

            echo "Build Number : ${BUILD_NUMBER}"

            echo "GitLab Repository : ${GITLAB_REPOSITORY}"


            sh '''
                echo "===== FINAL EC2 DETAILS ====="


                if [ -f ec2-details.env ]; then

                    cat ec2-details.env

                else

                    echo "EC2 details were not generated."

                fi
            '''
        }
    }
}