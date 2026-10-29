pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        IMAGE_NAME = 'ci-cd-webapp'
        K8S_NAMESPACE = 'default'
        K8S_DEPLOYMENT = 'ci-cd-webapp'
        K8S_CONTAINER = 'web'
        K8S_SERVICE = 'ci-cd-webapp-service'
        NODE_PORT = '30080'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm

                echo 'Source code checked out successfully.'
            }
        }

        stage('Test Application') {
            steps {
                sh '''
                    set -eu

                    echo "Checking required project files..."

                    test -f index.html
                    test -f Dockerfile
                    test -f k8s/deployment.yaml

                    echo "Checking application title..."
                    grep -q "LaunchPad | Project Dashboard" index.html

                    echo "Checking application content..."
                    grep -q "Featured projects" index.html
                    grep -q "Today's focus" index.html

                    echo "Checking Dockerfile..."
                    grep -q "FROM nginx:alpine" Dockerfile

                    echo "Checking Kubernetes configuration..."
                    grep -q "kind: Deployment" k8s/deployment.yaml
                    grep -q "kind: Service" k8s/deployment.yaml

                    echo "All application checks passed."
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKERHUB_USER',
                        passwordVariable: 'DOCKERHUB_TOKEN'
                    )
                ]) {
                    sh '''
                        set -eu

                        IMAGE="$DOCKERHUB_USER/$IMAGE_NAME:$BUILD_NUMBER"
                        LATEST_IMAGE="$DOCKERHUB_USER/$IMAGE_NAME:latest"

                        docker build \
                            -t "$IMAGE" \
                            -t "$LATEST_IMAGE" .
                    '''
                }
            }
        }

        stage('Push Image to Docker Hub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKERHUB_USER',
                        passwordVariable: 'DOCKERHUB_TOKEN'
                    )
                ]) {
                    sh '''
                        set -eu

                        export DOCKER_CONFIG="$WORKSPACE/.docker-auth-$BUILD_NUMBER"
                        mkdir -p "$DOCKER_CONFIG"

                        cleanup() {
                            docker logout >/dev/null 2>&1 || true
                            rm -rf "$DOCKER_CONFIG"
                        }

                        trap cleanup EXIT

                        printf '%s' "$DOCKERHUB_TOKEN" |
                            docker login \
                                --username "$DOCKERHUB_USER" \
                                --password-stdin

                        docker push \
                            "$DOCKERHUB_USER/$IMAGE_NAME:$BUILD_NUMBER"

                        docker push \
                            "$DOCKERHUB_USER/$IMAGE_NAME:latest"
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKERHUB_USER',
                        passwordVariable: 'DOCKERHUB_TOKEN'
                    )
                ]) {
                    sh '''
                        set -eu

                        IMAGE="$DOCKERHUB_USER/$IMAGE_NAME:$BUILD_NUMBER"

                        echo "Checking Kubernetes context..."
                        kubectl config current-context

                        echo "Applying Kubernetes manifests..."
                        kubectl apply \
                            -f k8s/deployment.yaml \
                            -n "$K8S_NAMESPACE"

                        echo "Updating application image..."
                        kubectl set image \
                            "deployment/$K8S_DEPLOYMENT" \
                            "$K8S_CONTAINER=$IMAGE" \
                            -n "$K8S_NAMESPACE"

                        echo "Waiting for rollout..."
                        kubectl rollout status \
                            "deployment/$K8S_DEPLOYMENT" \
                            --timeout=180s \
                            -n "$K8S_NAMESPACE"
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    set -eu

                    echo "Deployment status:"
                    kubectl get deployment "$K8S_DEPLOYMENT" \
                        -n "$K8S_NAMESPACE"

                    echo "Pods:"
                    kubectl get pods \
                        -l app=ci-cd-webapp \
                        -n "$K8S_NAMESPACE"

                    echo "Service:"
                    kubectl get service "$K8S_SERVICE" \
                        -n "$K8S_NAMESPACE"

                    echo "Application URL:"
                    echo "http://localhost:$NODE_PORT"
                '''
            }
        }
    }

    post {
        success {
            echo 'CI/CD pipeline completed successfully.'
            echo 'The application has been deployed to Kubernetes.'
        }

        failure {
            echo 'Pipeline failed. Inspect the failed stage in the Jenkins console output.'
        }

        always {
            echo 'Pipeline execution finished.'
        }
    }
}
