# NTI DevOps Final Project

Module-based AWS infrastructure and an example full-stack application. The core Terraform defaults use `us-east-1` and the resource prefix `nti-devops`. Multibranch deployment destinations are configured separately per branch with `pipeline_environments`; the Jenkinsfile discovers the selected branch and does not need editing when a target changes.

## Project map

- `terraform/`: VPC, configurable EKS managed node group, RDS + Secrets Manager, Jenkins EC2, daily AWS Backup, ECR, and an internet-facing ALB with access logs in S3. Each Git branch contains only its matching Terraform variables file: `main.tfvars`, `dev.tfvars`, `stage.tfvars`, or `prod.tfvars`.
- `ansible/`: Jenkins tools/plugins and CloudWatch Agent for EC2 instances in its inventory.
- `app/`: HTML/JS frontend, Express API, MySQL local database, Dockerfiles, Compose, and the Helm chart used by the pipeline.
- `k8s/`: standalone, component-grouped YAML manifests with ConfigMaps and a gitignored local Secret file; the pipeline deploys the Helm chart in `app/helm/nti-app`.
- `monitoring/`: kube-prometheus-stack values, pod resource alerts, and Grafana dashboard.
- `Jenkinsfile`: multibranch build, SonarQube gate, Trivy scans, and branch-configured ECR/EKS deployment.

## Local app

Requires Docker Desktop with its Linux engine running:

```powershell
cd app
docker compose up --build
```

Open `http://localhost`. The API health endpoint is `http://localhost:3001/api/health`; Adminer is at `http://localhost:8081`. The local database credentials in Compose are for development only.

## AWS infrastructure

1. Configure AWS credentials and create an EC2 key pair in the target region.
2. Set `key_name` and `jenkins_access_cidr` in Terraform variables. The default access CIDR is localhost only; set it to your trusted public IP in `/32` form to reach Jenkins. Jenkins uses a dynamically selected Ubuntu 22.04 AMI, and the EKS default is Kubernetes `1.36` with Amazon Linux 2023 nodes.
3. Run:

```powershell
cd terraform
terraform init
terraform workspace new dev
terraform workspace select dev
terraform plan -var-file="dev.tfvars" -var="key_name=YOUR_EC2_KEY_PAIR" -var="jenkins_access_cidr=YOUR_PUBLIC_IP/32"
terraform apply -var-file="dev.tfvars" -var="key_name=YOUR_EC2_KEY_PAIR" -var="jenkins_access_cidr=YOUR_PUBLIC_IP/32"
```

The `main`, `dev`, `stage`, and `prod` branches each contain only the correspondingly named `.tfvars` file. Select the matching Terraform workspace and use that branch's file when planning or applying. Keep each environment in its own workspace/state; if resources already exist in the `default` workspace, review and migrate state deliberately before creating another copy. The environment files use distinct resource prefixes and VPC ranges, and EKS/RDS sizing is passed to modules through Terraform variables.

Terraform creates billable AWS resources. Review the plan, particularly NAT gateways, EKS nodes, RDS, and Jenkins EC2, before applying. Keep Terraform state private because it contains generated database credentials.

The EC2 `t3.micro` defaults may qualify for an account's Free Tier, but eligibility varies by account and region. EKS control-plane time, NAT gateways, load balancers, and other resources in this stack can still incur charges. RDS automated backups default to disabled (`rds_backup_retention_period = 0`) to satisfy Free Tier account limits; set a supported retention period if your account permits it.

When recovering a failed apply, keep using the same variable inputs that created the current workspace state. Review the plan before switching to a branch-specific `.tfvars` file: changing project names or CIDRs can replace the VPC and dependent resources.

For remote state, do this before initializing the core configuration: run `terraform -chdir=terraform/bootstrap init` and `terraform -chdir=terraform/bootstrap apply -var="state_bucket_name=YOUR_GLOBALLY_UNIQUE_BUCKET"`. Copy `terraform/backend.tf.example` to `terraform/backend.tf` and `terraform/backend.hcl.example` to `terraform/backend.hcl`, then set the bucket output in the HCL file. Initialize with `terraform -chdir=terraform init -backend-config=backend.hcl` (use `-migrate-state` if migrating an existing local workspace). For addons, copy the corresponding backend examples from `terraform/addons/` and use its separate state key. The local backend files are gitignored.

After the core apply creates the EKS cluster and OIDC provider, run `./terraform/apply-addons.ps1` from PowerShell. It reads the required values from core Terraform outputs and uses the matching addons workspace, so dev/stage addon state remains isolated, then installs External Secrets Operator plus the application namespace in a second Terraform pass, after the API server exists.

The ALB target group attaches to the EKS managed node group's Auto Scaling Group on NodePort `30080`; the frontend Service and ALB health checks must keep that port aligned. The ALB DNS output is the application URL after the Helm deployment is healthy.

This implementation uses a Terraform-managed ALB directly attached to the EKS node group; it does not install AWS Load Balancer Controller or create a Kubernetes `Ingress`. Replacing it requires an explicit ALB/state migration to avoid destroying an existing load balancer or creating a duplicate.

## Configure Jenkins

1. From `ansible/`, install the `amazon.aws` collection with `ansible-galaxy collection install -r requirements.yml` and install its `boto3`/`botocore` Python dependencies. Export `AWS_REGION` and `JENKINS_SSH_KEY` for the AWS region and EC2 private key, then run `ansible-playbook jenkins.yml`. The AWS EC2 inventory discovers Jenkins by its `Project`/`Name` tags.
2. The Jenkins play prompts for the Jenkins admin password, current/new SonarQube admin passwords, and the SonarQube database password. For a fresh SonarQube install, the current password is `admin`; choose and securely retain the new value for future playbook runs.
3. Jenkins JCasC configures the SonarQube server named `SonarQube`, creates the token credential, and registers the quality-gate webhook. SonarQube listens on EC2 loopback at port 9000, not on the public interface.
4. Create a GitHub multibranch Pipeline pointing to this repository and set its branch indexing interval to one minute. Jenkins is intentionally reachable only from `jenkins_access_cidr`, so a public GitHub webhook cannot reach it unless you separately allow GitHub's published webhook IP ranges.
5. Multibranch Pipeline discovers branch jobs from Git; the Jenkinsfile reads `BRANCH_NAME` at runtime, so environment values are not embedded in the pipeline. Build and security scans run on branches and pull requests. App deployment occurs only for branches listed in `pipeline_environments`; `main` is build/scan-only unless it is explicitly configured there.
6. Provision the target deployment role in each app deployment environment first, then configure `pipeline_environments` in the untracked `terraform/terraform.tfvars` file and apply the root Terraform configuration using the matching branch's `.tfvars` file (for example, `-var-file=dev.tfvars`). This creates the non-secret Systems Manager Parameter Store entries Jenkins reads for the selected branch:

   ```hcl
   pipeline_environments = {
     dev = {
       aws_region         = "<dev-region>"
       role_arn           = "arn:aws:iam::<dev-account-id>:role/<project>-jenkins-deploy"
       cluster_name       = "<dev-cluster>"
       ecr_repository_uri = "<dev-account-id>.dkr.ecr.<dev-region>.amazonaws.com/<dev-repository>"
       namespace          = "<dev-namespace>"
       secret_id          = "<dev-database-secret-id>"
     }
     stage = {
       aws_region         = "<stage-region>"
       role_arn           = "arn:aws:iam::<stage-account-id>:role/<project>-jenkins-deploy"
       cluster_name       = "<stage-cluster>"
       ecr_repository_uri = "<stage-account-id>.dkr.ecr.<stage-region>.amazonaws.com/<stage-repository>"
       namespace          = "<stage-namespace>"
       secret_id          = "<stage-database-secret-id>"
     }
     prod = {
       aws_region         = "<prod-region>"
       role_arn           = "arn:aws:iam::<prod-account-id>:role/<project>-jenkins-deploy"
       cluster_name       = "<prod-cluster>"
       ecr_repository_uri = "<prod-account-id>.dkr.ecr.<prod-region>.amazonaws.com/<prod-repository>"
       namespace          = "<prod-namespace>"
       secret_id          = "<prod-database-secret-id>"
     }
   }
   ```

   These are identifiers, not secret values. Keep database credentials only in Secrets Manager. Each target role must trust the exact Jenkins EC2 role, have ECR push access limited to that environment's repository, `eks:DescribeCluster` limited to that cluster, and an EKS access entry/policy limited to that namespace. Pre-create each target namespace and configure External Secrets with read access only to that environment's database secret. The source Jenkins role can read only this project's pipeline parameters and assume only the role ARNs declared in `pipeline_environments`.
7. The Jenkins EC2 role uses IMDSv2 and must retain the Terraform-managed instance role and metadata settings. For untrusted fork/PR jobs, use Jenkins trusted revisions and isolated agents without an AWS instance profile or IMDS access; a Jenkinsfile cannot protect a privileged host from malicious pipeline code. Protect `prod` with GitHub branch protection and Jenkins authorization/approval controls.

## Monitoring

Follow [monitoring/README.md](monitoring/README.md) after the EKS cluster is ready. kube-prometheus-stack discovers Kubernetes nodes and pods, raises CPU/memory alerts at 80% of container limits for five minutes, and loads the included Grafana dashboard. EKS worker nodes use the CloudWatch Observability add-on; Ansible installs the agent on Jenkins EC2.

## Verification

```powershell
terraform -chdir=terraform validate
helm lint app/helm/nti-app
docker compose -f app/docker-compose.yml config
```
