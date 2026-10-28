# Terraform Assignment – Task 3: AWS ECS, ECR, VPC and ALB

**Project:** Terraform Assignment – Part 3  
**Cloud Provider:** Amazon Web Services (AWS)  
**Region:** Asia Pacific (Mumbai) – `ap-south-1`  
**Tools:** Terraform, Docker, Amazon ECR, Amazon ECS, AWS VPC, Application Load Balancer and CloudWatch Logs

## 1. Project Overview

The goal of this task was to deploy a containerized web application on AWS using Terraform.

The application has two separate components:

- **Frontend:** An Express.js application that displays a contact form.
- **Backend:** A Flask application that processes the submitted form data and provides a health-check API.

Both applications were packaged into Docker images, uploaded to Amazon Elastic Container Registry (ECR), and deployed as separate Amazon ECS Fargate services.

Terraform was used to create and manage the AWS infrastructure. An Application Load Balancer (ALB) receives incoming HTTP requests and forwards them to the appropriate application.

This task helped me practise containerization, infrastructure as code, AWS networking, container deployment, load balancing, health checks, and Terraform state management.

## 2. Architecture

The application follows this request flow:

```text
                         Internet
                            |
                            v
                  Application Load Balancer
                         HTTP :80
                            |
                 +----------+----------+
                 |                     |
             Normal URLs            /api/*
                 |                     |
                 v                     v
          Express Frontend        Flask Backend
              Port 3000             Port 5000
                 |                     |
                 +----------+----------+
                            |
                     ECS Fargate
                    Private Subnets

          Docker Images stored in Amazon ECR

          ECS Container Logs -> CloudWatch Logs
```

The ALB is deployed in public subnets, while the ECS tasks run in private subnets without public IP addresses.

The frontend communicates with the backend through the ALB's `/api/*` routing rule. Security groups restrict application-port access to traffic coming from the ALB.

A NAT Gateway provides outbound connectivity for the private subnets.

## 3. AWS Resources Created

Terraform successfully created **30 resources** during the deployment.

The infrastructure includes:

- Two Amazon ECR repositories for the frontend and backend images.
- One dedicated VPC using CIDR `10.30.0.0/16`.
- Two public subnets and two private subnets.
- An Internet Gateway and route tables.
- One NAT Gateway for outbound connectivity.
- One internet-facing Application Load Balancer.
- Two ALB target groups and the associated listener rules.
- One Amazon ECS cluster.
- Two ECS Fargate services and their task definitions.
- An IAM task execution role and policy attachment.
- Two CloudWatch log groups.

The deployment completed with the following Terraform result:

```text
Apply complete! Resources: 30 added, 0 changed, 0 destroyed.
```

The ECS cluster became active, and both frontend and backend services reached the running state.

## 4. Docker Images and Amazon ECR

Before deploying the application, I built and tested both Docker images locally.

| Application | Local Docker image |
|---|---|
| Flask backend | `anuj-flask-backend:latest` |
| Express frontend | `anuj-express-frontend:latest` |

Both images were successfully built and uploaded to their respective ECR repositories.

**Backend repository**

`terraform-assignment-part-3-backend`

**Frontend repository**

`terraform-assignment-part-3-frontend`

AWS account: `525360104564`  
Region: `ap-south-1`  
Image tag: `build-20261028-1`

The repositories use immutable image tags and scan-on-push configuration.

The successful ECR upload was verified using AWS CLI commands and the AWS Management Console.

## 5. Terraform Configuration

The Terraform configuration is divided into separate files to keep the infrastructure easier to understand and maintain.

| File | Purpose |
|---|---|
| `versions.tf` | Terraform version requirements and S3 backend configuration |
| `providers.tf` | AWS provider configuration |
| `variables.tf` | Configurable deployment values |
| `locals.tf` | Shared local values and resource naming |
| `ecr.tf` | ECR repository creation |
| `vpc.tf` | VPC, subnets, gateways and routing |
| `security.tf` | Security groups and traffic rules |
| `ecs.tf` | ECS cluster, task definitions, IAM role and services |
| `alb.tf` | Application Load Balancer, target groups and routing |
| `outputs.tf` | Useful deployment outputs |
| `terraform.tfvars.example` | Example variable configuration |
| `ecr/` | Dockerfiles for the frontend and backend |
| `scripts/` | PowerShell scripts for building and pushing images |

The actual `terraform.tfvars` file contains the deployment-specific image URIs and should remain uncommitted.

### Terraform validation

Before deployment, I checked the Terraform configuration using:

```powershell
terraform fmt -check -recursive
terraform validate
```

The formatting check passed, and Terraform validation returned:

```text
Success! The configuration is valid.
```

I then reviewed the execution plan before applying it.

## 6. Terraform Remote State

Terraform state is stored in an S3 bucket so that the infrastructure state is maintained remotely.

The configured state bucket is:

`anujbansal-terraform-state-525360104564-ap-south-1`

The state key is:

`terraform-assignment-part-3/terraform.tfstate`

The bucket was configured with:

- S3 bucket versioning enabled.
- Server-side encryption using AES-256.
- All four S3 public-access-block settings enabled.
- Native S3 state locking using Terraform's `use_lockfile` option.

The backend was initialized successfully, and the remote state was checked before the deployment.

The state bucket is separate from the Task 3 application resources and should be retained after cleaning up the deployment.

## 7. Application Deployment and Testing

After applying the Terraform plan, I tested the deployed application through the ALB.

**Frontend URL**

http://terraform-assignment-part-3-1910509511.ap-south-1.elb.amazonaws.com/

**Backend health endpoint**

http://terraform-assignment-part-3-1910509511.ap-south-1.elb.amazonaws.com/api/health

### Frontend test

The frontend returned:

```text
StatusCode        : 200
StatusDescription : OK
```

The response contained the Express contact-form HTML.

### Backend health check

The `/api/health` endpoint returned:

```text
service       status
-------       ------
flask-backend ok
```

This confirmed that the Flask backend was responding successfully through the ALB.

### ECS service verification

In the AWS Management Console, I verified that:

- The ECS cluster status was Active.
- Both frontend and backend services were Active.
- Both services had one running task.
- No tasks were pending in the cluster overview.

### ALB target-group verification

Both target groups showed one healthy target and zero unhealthy targets.

| Target group | Port | Result |
|---|---:|---|
| `tf-p3-frontend-tg` | 3000 | Healthy |
| `tf-p3-backend-tg` | 5000 | Healthy |

### End-to-end form submission

I opened the deployed contact form and submitted test data.

The application displayed the **“Message submitted”** confirmation page with the submitted values.

This verified the complete request flow from the Express frontend through the ALB to the Flask backend.

## 8. Screenshots and Evidence

The screenshots are stored in the repository-level directory:

`Screenshots/06 ecr ecs vpc/`

The evidence is organized into the following folders:

| Folder | Evidence |
|---|---|
| `01 preparation` | Project structure and initial preparation |
| `02docker build` | Docker image builds and local testing |
| `03 ecr` | ECR repositories, image tags and image uploads |
| `04 terraform` | Terraform plan, validation and successful apply |
| `05 ecs` | ECS cluster and running services |
| `06 alb testing` | Frontend, backend health, target groups and form submission |

These screenshots document the actual commands, AWS console screens, and application test results.

## 9. Cost and Security Considerations

This deployment was created for learning and assignment purposes. It is not intended to be a production-ready architecture without further security and reliability improvements.

The following points should be considered:

- **NAT Gateway:** Can incur hourly and data-processing charges.
- **Application Load Balancer:** Can incur hourly and usage-based charges.
- **ECS Fargate:** Charges apply while tasks run.
- **Amazon ECR:** Image storage and data transfer may incur charges.
- **CloudWatch Logs:** Log ingestion and storage may incur charges.
- **HTTP:** The current ALB listener uses HTTP on port 80; HTTPS has not been configured.
- **Production security:** HTTPS, tighter egress rules, and additional monitoring should be considered before production use.

The infrastructure should be destroyed after the assignment evidence has been captured if the resources are no longer required.

## 10. Cleanup Procedure

The Task 3 infrastructure should be removed through Terraform rather than by manually deleting individual AWS resources.

First, confirm the working directory and workspace:

```powershell
terraform workspace show
terraform state list
```

Generate and review the destroy plan:

```powershell
terraform plan -destroy -out="task3-destroy.tfplan"
```

Carefully check that the plan contains only Task 3 resources. Do not proceed if it includes resources from Task 1 or Task 2.

After reviewing the plan, apply it:

```powershell
terraform apply "task3-destroy.tfplan"
```

**Important:** The ECR repositories contain uploaded images. If repository deletion is blocked because the repositories are not empty, remove the Task 3 images using the approved cleanup procedure and retry Terraform cleanup.

After destruction, verify that the Task 3 ALB, ECS services, NAT Gateway, networking resources, CloudWatch log groups, and ECR repositories have been removed.

Keep the S3 Terraform state bucket and its state object unless there is a separate, approved reason to remove them. Do not delete Task 1 or Task 2 resources.

## 11. Final Status

### Completed

- Docker images built successfully.
- Images uploaded to Amazon ECR.
- Terraform configuration formatted and validated.
- S3 remote state configured.
- Terraform deployment completed successfully with 30 resources created.
- ECS cluster and both services verified.
- Frontend and backend target groups verified as healthy.
- Frontend HTTP response tested successfully.
- Backend health endpoint tested successfully.
- Contact-form submission tested successfully.
- AWS console and application screenshots captured.

### Remaining

- Finalize and commit the assignment documentation and evidence.
- Review the Git working tree and ensure unrelated files are excluded.
- Destroy the Task 3 application infrastructure to prevent unnecessary ongoing AWS charges.
- Verify the cleanup while preserving the S3 state bucket and Task 1 and Task 2 resources.

