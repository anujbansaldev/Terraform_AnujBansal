 Task 3
This directory prepares a containerized Flask backend and Express frontend for deployment on AWS using Amazon ECR, ECS Fargate, a dedicated VPC, and an Application Load Balancer (ALB).

Current status: local Terraform validation and local container testing have passed. The AWS account and region were verified, but no Task 3 Terraform apply or AWS deployment has been performed. The ECR listing was verified and currently returned no repositories.

## 1. Task overview and objectives

Task 3 implements the following assignment objectives:

- Create separate ECR repositories for the Flask backend and Express frontend.
- Build Docker images from the existing shared application source.
- Run the images as two ECS Fargate services.
- Place the services in private subnets inside a dedicated VPC.
- Place an internet-facing ALB in two public subnets.
- Route normal web traffic to Express and `/api/*` traffic to Flask.
- Use security groups so application ports are reachable from the ALB, not directly from the internet.
- Send ECS container logs to CloudWatch Logs with a configurable retention period.
- Prepare Terraform variables, outputs, formatting, validation, planning, deployment, state, testing, screenshot, and cleanup workflows.

The intended AWS account is `525360104564`, the configured region is `ap-south-1`, and the default project prefix is `terraform-assignment-part-3`.

## 2. Architecture

```text
Internet
   |
   | HTTP :80
   v
Public ALB in two public subnets
   |-- default route --> Express ECS service :3000
   |-- /api/* route --> Flask ECS service :5000

Private subnet 1             Private subnet 2
Express Fargate task         Flask Fargate task(s)
        \                       /
         \-- outbound through one NAT Gateway

ECR repositories --> ECS task image pulls
ECS tasks ---------> CloudWatch Logs
```

Terraform creates:

- Two ECR repositories with names derived from the project prefix:
  - `terraform-assignment-part-3-backend`
  - `terraform-assignment-part-3-frontend`
- A VPC using `10.30.0.0/16`.
- Two public subnets using `10.30.1.0/24` and `10.30.2.0/24`.
- Two private subnets using `10.30.11.0/24` and `10.30.12.0/24`.
- An Internet Gateway and public route table.
- One NAT Gateway in the first public subnet for private-task outbound access.
- An internet-facing ALB in the public subnets.
- Two target groups: Express on port `3000` and Flask on port `5000`.
- Two ECS Fargate services with `assign_public_ip = false`.
- CloudWatch log groups with a default retention of 7 days.
- An ECS task execution role using `AmazonECSTaskExecutionRolePolicy` for ECR pulls and CloudWatch Logs.

The Flask backend is not directly exposed to the internet. The ECS security group permits ports `3000` and `5000` only from the ALB security group. The ALB security group permits public HTTP port `80`.

The frontend task receives `BACKEND_URL` as the ALB DNS name. Its server-side calls to `/api/health` and `/api/submit` therefore reach Flask through the ALB `/api/*` listener rule.

## 3. Project file structure

The following files currently exist in this Task 3 directory:

```text
part-3-ecr-ecs-vpc/
├── .terraform.lock.hcl
├── alb.tf
├── ecr.tf
├── ecs.tf
├── locals.tf
├── outputs.tf
├── providers.tf
├── README.md
├── security.tf
├── terraform.tfvars.example
├── variables.tf
├── versions.tf
├── vpc.tf
├── ecr/
│   ├── backend.Dockerfile
│   └── frontend.Dockerfile
├── scripts/
│   ├── build-images.ps1
│   └── push-images.ps1
├── alb/
├── ecs/
└── vpc/
```

The `alb`, `ecs`, and `vpc` directories currently contain no additional files; the active Terraform configuration is in the root `.tf` files. The `.terraform` provider cache may exist locally after `terraform init`, but it is generated and should not be committed.

The shared application source remains outside this directory:

```text
applications/backend/
applications/frontend/
```

The Dockerfiles use the repository root as their build context and copy only the required application files.

## 4. Prerequisites

Install or configure:

- AWS CLI.
- Terraform `>= 1.5.0, < 2.0.0`.
- Docker Desktop with the Linux container engine running.
- An approved AWS credential source such as an AWS CLI profile, environment-based credentials, or another non-source-controlled mechanism.
- Network access to download Terraform providers and Docker base images.

The AWS identity must be permitted to perform the deployment operations required by the plan, including management of VPC, EC2 networking, ECR, ECS, IAM roles and policy attachments, Elastic Load Balancing, CloudWatch Logs, and related resources. The exact IAM policy should be approved for the account before deployment. Do not store access keys, tokens, or credentials in this repository.

Verify the account and region before using Terraform:

```powershell
aws sts get-caller-identity
aws configure get region
```

The verified account is `525360104564` and the intended region is `ap-south-1`. Reconfirm them in the deployment environment.

## 5. Local Docker builds

Run these commands from the repository root, not from inside `part-3-ecr-ecs-vpc`. The final `.` is important because the Dockerfiles copy from `applications/backend` and `applications/frontend`.

```powershell
docker build `
  -f .\part-3-ecr-ecs-vpc\ecr\backend.Dockerfile `
  -t anuj-flask-backend:latest `
  .

docker build `
  -f .\part-3-ecr-ecs-vpc\ecr\frontend.Dockerfile `
  -t anuj-express-frontend:latest `
  .
```

The backend image installs `Flask==3.0.3` from the shared requirements file and pinned `gunicorn==23.0.0` in the Dockerfile. It starts `gunicorn` with the entry point `app:app` on `0.0.0.0:5000`.

The frontend image installs the existing `package.json`/`package-lock.json` dependencies and starts `server.js` on port `3000`.

Verified progress: both local images built successfully with the tags `anuj-flask-backend:latest` and `anuj-express-frontend:latest`.

## 6. Local container testing

Start the backend first:

```powershell
docker run --rm -d `
  --name task3-backend `
  -p 5000:5000 `
  anuj-flask-backend:latest
```

Test the Flask health endpoint:

```powershell
Invoke-RestMethod http://localhost:5000/api/health
```

Expected response content includes `status: ok` and `service: flask-backend`.

Start the frontend. Docker Desktop's `host.docker.internal` lets the frontend container reach the backend port published on the host:

```powershell
docker run --rm -d `
  --name task3-frontend `
  -e BACKEND_URL=http://host.docker.internal:5000 `
  -p 3000:3000 `
  anuj-express-frontend:latest
```

Test the frontend page and frontend-to-backend health route:

```powershell
Invoke-WebRequest http://localhost:3000/
Invoke-RestMethod http://localhost:3000/api/health
```

The frontend root should return HTML. The frontend health route calls the configured backend and should report the Express service plus the Flask backend response.

Stop the local containers when finished:

```powershell
docker stop task3-frontend task3-backend
```

Verified progress: the backend health endpoint returned a successful `flask-backend / ok` result, and the frontend root returned HTML. Docker Desktop must be running for these commands; no Docker build result should be inferred when the Docker engine is unavailable.

## 7. ECR repositories and image tagging

The Terraform resources in `ecr.tf` derive repository names from `var.project_name`:

```text
${project_name}-backend
${project_name}-frontend
```

With the current default prefix, the intended repository names are:

```text
terraform-assignment-part-3-backend
terraform-assignment-part-3-frontend
```

The verified account and region produce these intended URI prefixes:

```text
525360104564.dkr.ecr.ap-south-1.amazonaws.com/terraform-assignment-part-3-backend
525360104564.dkr.ecr.ap-south-1.amazonaws.com/terraform-assignment-part-3-frontend
```

The ECR listing currently returned no repositories, so these repositories are pending Terraform creation.

Use a unique immutable tag for each image. The repositories are configured with immutable tags, so do not reuse an existing tag after pushing it:

```powershell
$account = "525360104564"
$region = "ap-south-1"
$tag = "2026-10-28"
$backendRepo = "$account.dkr.ecr.$region.amazonaws.com/terraform-assignment-part-3-backend"
$frontendRepo = "$account.dkr.ecr.$region.amazonaws.com/terraform-assignment-part-3-frontend"

docker tag anuj-flask-backend:latest "$backendRepo`:$tag"
docker tag anuj-express-frontend:latest "$frontendRepo`:$tag"

aws ecr get-login-password --region $region |
  docker login --username AWS --password-stdin "$account.dkr.ecr.$region.amazonaws.com"

docker push "$backendRepo`:$tag"
docker push "$frontendRepo`:$tag"
```

The `scripts/push-images.ps1` script performs the login and pushes both supplied repository/tag combinations. It is a deployment action and has not been run as part of the verified preparation status.

After the repositories and images exist, place the full image URIs in a local, uncommitted `terraform.tfvars` file based on `terraform.tfvars.example`:

```hcl
backend_image  = "525360104564.dkr.ecr.ap-south-1.amazonaws.com/terraform-assignment-part-3-backend:2026-10-28"
frontend_image = "525360104564.dkr.ecr.ap-south-1.amazonaws.com/terraform-assignment-part-3-frontend:2026-10-28"
```

## 8. Terraform workflow

Change to this directory:

```powershell
Set-Location .\part-3-ecr-ecs-vpc
```

Create local variables without committing them:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Replace any placeholder values and confirm `aws_region`, `availability_zones`, and both image URIs.

Initialize the currently configured local backend and provider:

```powershell
terraform init
```

Format and validate without creating AWS resources:

```powershell
terraform fmt -check -recursive
terraform validate
```

Create a reviewed plan:

```powershell
terraform plan `
  -var-file=terraform.tfvars `
  -out=task3.tfplan
```

Review the plan carefully for the correct account, region, project prefix, subnets, security groups, ECR image URIs, and resource count. Only after explicit deployment approval should the plan be applied:

```powershell
terraform apply task3.tfplan
```

Current verified progress: `terraform validate` passed. No Task 3 `terraform apply`, deployment, import, or destroy has been performed.

Useful outputs after deployment:

```powershell
terraform output -raw frontend_url
terraform output -raw backend_health_url
terraform output -raw alb_dns_name
```

## 9. S3 remote state: pending setup

Remote state is not currently configured. In `versions.tf`, the S3 backend is commented out:

```hcl
# backend "s3" {}
```

No bucket name, lock configuration, or remote backend should be assumed. The assignment requires evaluating remote state, but this preparation intentionally does not create the bucket or modify AWS resources.

Before a shared deployment:

1. Obtain approval for a unique S3 state bucket and state key.
2. Bootstrap the bucket separately with versioning, encryption, and public access blocked.
3. Configure the approved state-locking mechanism supported by the selected Terraform version.
4. Add the approved `backend "s3"` configuration to `versions.tf` without committing credentials.
5. Back up and review any existing local state.
6. Run `terraform init -migrate-state` only after confirming the backend destination and migration prompt.
7. Verify that the state was migrated to the intended account, region, bucket, and key.

Do not commit `terraform.tfstate`, `.tfstate.*`, `terraform.tfvars`, plans, credentials, or access keys. Do not create an S3 bucket automatically from this Task 3 configuration.

## 10. ALB verification, logs, and troubleshooting

After deployment, obtain the ALB URL:

```powershell
$frontendUrl = terraform output -raw frontend_url
$backendHealthUrl = terraform output -raw backend_health_url

Invoke-WebRequest $frontendUrl
Invoke-RestMethod $backendHealthUrl
```

Expected routes:

- `GET /` → Express frontend target group on port `3000`.
- `GET /api/health` → Flask backend target group on port `5000`.
- `POST /submit` → Express, which calls Flask through the configured ALB `/api/*` route.

The ALB health checks are:

- Express: `/`, accepting HTTP `200–399`.
- Flask: `/api/health`, requiring HTTP `200`.

CloudWatch log groups are named:

```text
/ecs/terraform-assignment-part-3/backend
/ecs/terraform-assignment-part-3/frontend
```

Troubleshooting sequence:

1. Confirm the ECR image URI and immutable tag in `terraform.tfvars`.
2. Confirm the image was pushed to the intended account and region.
3. Inspect ECS service events and stopped task reasons.
4. Check that the task execution role can pull from ECR and write logs.
5. Check target group health and the container ports `3000` and `5000`.
6. Check the ECS security group allows traffic from the ALB security group.
7. Check NAT Gateway/private route-table connectivity for image pulls and logs.
8. Review the backend and frontend CloudWatch log groups.

No ALB, ECS, ECR, or CloudWatch deployment result is claimed until it is actually performed and tested.

## 11. Screenshot checklist

The Task 3 directory currently has no `Screenshots` subdirectory. The repository-level `Screenshots/06 ecr ecs vpc` directory exists. Store only real evidence in the approved existing screenshot location, or create a Task 3 screenshot structure only through a separate approved change.

Suggested evidence checklist:

- Preparation: verified account, region, Terraform version, Docker version, and project layout.
- Docker build: successful backend and frontend image build output.
- ECR: both repository names and pushed image tags after actual creation/push.
- Terraform: formatted configuration, validation output, plan summary, and outputs.
- ECS: cluster, task definitions, services, running task count, and service events.
- ALB testing: frontend page, `/api/health`, form submission, and target health.
- Logs: backend and frontend CloudWatch log streams.
- Git submission: final status showing no state files, credentials, plans, or unrelated assignment changes.

Do not create or submit invented screenshots. The current verified progress does not include deployed AWS screenshots.

## 12. Cost and security warnings

- NAT Gateway: incurs hourly and data-processing charges. The current design uses one NAT Gateway for both private subnets, which reduces cost but creates a cross-AZ resilience tradeoff.
- ALB: incurs hourly and usage-based charges. The current listener is public HTTP on port `80`; HTTPS/TLS is not configured.
- ECS Fargate: charges for requested CPU and memory while tasks run. The default is one task per service with `256` CPU and `512` MiB memory.
- ECR: image storage and data transfer may incur charges. Images use immutable tags and scan-on-push.
- CloudWatch: log ingestion and storage incur charges. The default retention is 7 days.
- Security groups: application ingress is restricted to the ALB security group, but ALB HTTP ingress is public and task egress is broad for NAT/ECR/log connectivity.
- Production safeguards not currently configured include HTTPS certificates/redirects, ALB access logs, WAF, deletion protection, and one NAT Gateway per AZ.

Review the cost and security posture before using this learning configuration for a production workload.

## 13. Cleanup

Cleanup must be performed only after deployment approval and only from the intended Task 3 Terraform directory and workspace:

```powershell
terraform workspace show
terraform state list
terraform plan -destroy -var-file=terraform.tfvars
```

Review the destroy plan carefully. Confirm that every resource has the `terraform-assignment-part-3` prefix and that no Task 1 or Task 2 resource is included. Then, only after confirmation:

```powershell
terraform destroy -var-file=terraform.tfvars
```

ECR repositories containing images may require image deletion before repository deletion unless a separately approved `force_delete` setting is added. Verify removal of the ALB, ECS services, target groups, NAT Gateway/EIP, route tables, subnets, VPC, CloudWatch log groups, and ECR repositories. Do not delete Task 1 or Task 2 infrastructure, state, or screenshots.

## Validation status

Verified:

- `terraform validate` passed.
- Both local images built successfully: `anuj-flask-backend:latest` and `anuj-express-frontend:latest`.
- Backend health returned a successful `flask-backend / ok` result at `http://localhost:5000/api/health`.
- Frontend returned HTML at `http://localhost:3000/`.
- AWS CLI identity and region were verified.
- ECR listing returned no repositories.

Pending:

- ECR repository creation and image pushes.
- Terraform plan using final image URIs.
- Terraform apply and AWS deployment.
- ALB, ECS, and CloudWatch verification.
- Production remote state bootstrap and migration.

## Files changed for this documentation update

Only this file was created or modified:

```text
part-3-ecr-ecs-vpc/README.md
```

Terraform files, application source, Dockerfiles, scripts, screenshots, and Tasks 1 and 2 were not modified.
