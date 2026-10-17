pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    skipDefaultCheckout(true)
  }

  environment {
    HELM_CHART = 'app/helm/nti-app'
    DEPLOY_ENABLED = 'false'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('SonarQube Analysis') {
      steps {
        withSonarQubeEnv('SonarQube') {
          sh '''
            sonar-scanner \
              -Dproject.settings=app/sonar-project.properties \
              -Dsonar.projectBaseDir=app
          '''
        }
      }
    }

    stage('SonarQube Quality Gate') {
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }

    stage('Build and Scan Images') {
      steps {
        script {
          if (!(env.GIT_COMMIT ==~ /[0-9a-fA-F]{40}/)) {
            error('Jenkins did not provide a valid Git commit SHA.')
          }
          def imageTag = sh(
            returnStdout: true,
            script: '''printf '%s' "$JOB_NAME/$BUILD_NUMBER/$GIT_COMMIT" | sha256sum | cut -c1-32'''
          ).trim()
          if (!(imageTag ==~ /[0-9a-f]{32}/)) {
            error('Could not generate a valid immutable image tag.')
          }
          env.IMAGE_TAG = imageTag
        }
        sh '''
          set -eu
          docker build --pull -t "app-backend:$IMAGE_TAG" app/backend
          docker build --pull -t "app-frontend:$IMAGE_TAG" app/frontend
          trivy image --exit-code 1 --scanners vuln,secret --severity CRITICAL,HIGH "app-backend:$IMAGE_TAG"
          trivy image --exit-code 1 --scanners vuln,secret --severity CRITICAL,HIGH "app-frontend:$IMAGE_TAG"
        '''
      }
    }

    stage('Resolve Branch Deployment') {
      when {
        not {
          changeRequest()
        }
        expression {
          return env.BRANCH_NAME?.trim()
        }
      }
      steps {
        script {
          def config = sh(
            returnStdout: true,
            script: '''
              #!/bin/sh
              set +x
              set -eu

              IMDS="http://169.254.169.254/latest"
              TOKEN=$(curl --fail --silent --show-error --max-time 3 -X PUT \
                -H "X-aws-ec2-metadata-token-ttl-seconds: 60" "$IMDS/api/token")
              BOOTSTRAP_REGION=$(curl --fail --silent --show-error --max-time 3 \
                -H "X-aws-ec2-metadata-token: $TOKEN" "$IMDS/meta-data/placement/region")
              PROJECT=$(curl --fail --silent --show-error --max-time 3 \
                -H "X-aws-ec2-metadata-token: $TOKEN" "$IMDS/meta-data/tags/instance/Project")

              case "$BOOTSTRAP_REGION" in
                ''|*[!a-z0-9-]*) echo "Invalid AWS region from instance metadata" >&2; exit 1 ;;
              esac
              case "$PROJECT" in
                ''|*[!a-z0-9-]*) echo "Invalid Project instance tag" >&2; exit 1 ;;
              esac
              case "$BRANCH_NAME" in
                ''|*[!a-z0-9-]*|-*|*-) printf 'SKIP'; exit 0 ;;
              esac
              if [ "${#BRANCH_NAME}" -gt 63 ]; then
                printf 'SKIP'
                exit 0
              fi

              ROOT="/$PROJECT/pipeline"
              ALLOWED_BRANCHES=$(aws ssm get-parameter \
                --region "$BOOTSTRAP_REGION" \
                --name "$ROOT/deploy-branches" \
                --query 'Parameter.Value' --output text)
              case ",$ALLOWED_BRANCHES," in
                *,"$BRANCH_NAME",*) ;;
                *) printf 'SKIP'; exit 0 ;;
              esac

              ENV_ROOT="$ROOT/environments/$BRANCH_NAME"
              get_parameter() {
                aws ssm get-parameter \
                  --region "$BOOTSTRAP_REGION" \
                  --name "$ENV_ROOT/$1" \
                  --query 'Parameter.Value' --output text
              }

              TARGET_REGION=$(get_parameter aws-region)
              DEPLOY_ROLE_ARN=$(get_parameter role-arn)
              EKS_CLUSTER_NAME=$(get_parameter cluster-name)
              ECR_REPOSITORY_URI=$(get_parameter ecr-repository-uri)
              K8S_NAMESPACE=$(get_parameter namespace)
              DATABASE_SECRET_ID=$(get_parameter secret-id)

              case "$TARGET_REGION" in
                ''|*[!a-z0-9-]*) echo "Invalid target AWS region" >&2; exit 1 ;;
              esac
              case "$K8S_NAMESPACE" in
                ''|*[!a-z0-9-]*|-*|*-) echo "Invalid Kubernetes namespace" >&2; exit 1 ;;
              esac
              if [ "${#K8S_NAMESPACE}" -gt 63 ]; then
                echo "Kubernetes namespace exceeds 63 characters" >&2
                exit 1
              fi
              case "$EKS_CLUSTER_NAME" in
                ''|*[!A-Za-z0-9_-]*) echo "Invalid EKS cluster name" >&2; exit 1 ;;
              esac
              case "$ECR_REPOSITORY_URI" in
                ''|*[!A-Za-z0-9._:/-]*) echo "Invalid ECR repository URI" >&2; exit 1 ;;
              esac
              case "$ECR_REPOSITORY_URI" in
                */*) ;;
                *) echo "ECR repository URI must include a repository path" >&2; exit 1 ;;
              esac
              case "$DEPLOY_ROLE_ARN" in
                arn:aws*:iam::*:role/*) ;;
                *) echo "Invalid deployment role ARN" >&2; exit 1 ;;
              esac
              case "$DATABASE_SECRET_ID" in
                ''|*[!A-Za-z0-9/_+=.@-]*) echo "Invalid database secret identifier" >&2; exit 1 ;;
              esac

              printf '%s\\n%s\\n%s\\n%s\\n%s\\n%s' \
                "$TARGET_REGION" "$DEPLOY_ROLE_ARN" "$EKS_CLUSTER_NAME" \
                "$ECR_REPOSITORY_URI" "$K8S_NAMESPACE" "$DATABASE_SECRET_ID"
            '''
          ).trim()

          if (config == 'SKIP') {
            echo "Branch '${env.BRANCH_NAME}' has no deployment configuration; build and scans completed without deployment."
          } else {
            def values = config.split('\\n')
            if (values.length != 6) {
              error('Branch deployment configuration is incomplete.')
            }

            env.AWS_REGION = values[0]
            env.DEPLOY_ROLE_ARN = values[1]
            env.EKS_CLUSTER_NAME = values[2]
            env.ECR_REPOSITORY_URI = values[3]
            env.K8S_NAMESPACE = values[4]
            env.DATABASE_SECRET_ID = values[5]
            env.DEPLOY_ENABLED = 'true'
          }
        }
      }
    }

    stage('Push and Deploy') {
      when {
        expression {
          env.DEPLOY_ENABLED == 'true'
        }
      }
      steps {
        sh '''
          #!/bin/sh
          set +x
          set -eu
          umask 077

          CREDENTIALS=$(aws sts assume-role \
            --role-arn "$DEPLOY_ROLE_ARN" \
            --role-session-name "jenkins-${BUILD_NUMBER}" \
            --duration-seconds 3600 \
            --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
            --output text)
          set -- $CREDENTIALS
          if [ "$#" -ne 3 ]; then
            echo "Could not assume the deployment role" >&2
            exit 1
          fi
          export AWS_ACCESS_KEY_ID="$1"
          export AWS_SECRET_ACCESS_KEY="$2"
          export AWS_SESSION_TOKEN="$3"
          unset AWS_PROFILE AWS_DEFAULT_PROFILE
          export AWS_REGION
          REGISTRY=${ECR_REPOSITORY_URI%%/*}

          aws ecr get-login-password --region "$AWS_REGION" |
            docker login --username AWS --password-stdin "$REGISTRY"
          docker tag "app-backend:$IMAGE_TAG" "$ECR_REPOSITORY_URI:backend-$IMAGE_TAG"
          docker tag "app-frontend:$IMAGE_TAG" "$ECR_REPOSITORY_URI:frontend-$IMAGE_TAG"
          docker push "$ECR_REPOSITORY_URI:backend-$IMAGE_TAG"
          docker push "$ECR_REPOSITORY_URI:frontend-$IMAGE_TAG"

          aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME"
          helm upgrade --install "$K8S_NAMESPACE" "$HELM_CHART" \
            --namespace "$K8S_NAMESPACE" \
            --set-string image.repository="$ECR_REPOSITORY_URI" \
            --set-string image.backendTag="backend-$IMAGE_TAG" \
            --set-string image.frontendTag="frontend-$IMAGE_TAG" \
            --set-string externalSecrets.region="$AWS_REGION" \
            --set-string externalSecrets.secretId="$DATABASE_SECRET_ID" \
            --atomic --wait --timeout 5m --history-max 10
        '''
      }
    }
  }

  post {
    always {
      sh '''
        #!/bin/sh
        set +x
        if [ -n "${IMAGE_TAG:-}" ]; then
          docker image rm "app-backend:$IMAGE_TAG" "app-frontend:$IMAGE_TAG" \
            >/dev/null 2>&1 || true
          if [ -n "${ECR_REPOSITORY_URI:-}" ]; then
            docker image rm \
              "$ECR_REPOSITORY_URI:backend-$IMAGE_TAG" \
              "$ECR_REPOSITORY_URI:frontend-$IMAGE_TAG" \
              >/dev/null 2>&1 || true
          fi
        fi
      '''
      cleanWs()
    }
  }
}
