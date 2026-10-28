# Task 2 v2: Separate EC2 deployment

This module deploys the unchanged Flask backend and Express frontend to two separate Amazon EC2 instances in `ap-south-1` by default.

## Architecture and request flow

```text
Client -> frontend public IP:3000 -> Express -> backend private IP:5000 -> Flask
```

- The backend and frontend have separate EC2 instances and security groups.
- The backend security group permits TCP 5000 only from the frontend security group.
- The frontend security group permits TCP 3000 only from `client_cidr`.
- SSH is permitted only from `trusted_ssh_cidr`.
- Both instances use the selected subnet and receive public IPv4 addresses so the bootstrap process can install packages.
- Both instances use the latest standard Amazon Linux 2023 x86_64 AMI ID returned by the regional AWS public SSM parameter `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`.
- Terraform checks that the selected `instance_type` supports `x86_64`.
- Terraform verifies that the subnet belongs to the selected VPC and has a default route through an internet gateway.
- The frontend receives `BACKEND_URL=http://<backend-private-ip>:5000` through Terraform interpolation.

The source repository is cloned by each user-data script. The repository must be publicly readable over HTTPS because bootstrap does not contain credentials and disables interactive Git authentication.

## Prerequisites

- Terraform compatible with `>= 1.5.0, < 2.0.0`.
- AWS CLI or another authenticated AWS session with permission to read the public SSM AMI parameter, selected VPC, subnet, route table, key pair, and instance type, and to create the assignment resources after approval.
- AWS provider access in the selected account and region.
- An existing EC2 key pair in the selected region. Only its name is placed in Terraform; never place a private key in this directory.
- The selected region must expose the AWS public SSM parameter used by the AMI data source. Terraform does not hardcode an AMI ID.
- An Amazon Linux 2023 package repository that provides the documented `nodejs22` and `nodejs22-npm` packages.
- A public HTTPS Git repository containing `applications/backend` and `applications/frontend`.
- A public client CIDR and a narrow SSH CIDR, preferably your current public IP with `/32`.

## Configuration

Copy `terraform.tfvars.example` to a local `terraform.tfvars` and set:

- `key_name`, `vpc_id`, and `subnet_id` for the target region.
- `trusted_ssh_cidr` for SSH access.
- `client_cidr` for frontend HTTP access.
- `application_source_url` and `application_source_ref` for the source repository.

The frontend installs the namespaced Amazon Linux 2023 packages `nodejs22` and `nodejs22-npm`. It uses the persistent executables `/usr/bin/node-22` and `/usr/bin/npm-22`, checks that the runtime is within Node.js 18-24, and exits before cloning if the expected runtime is unavailable. This avoids depending on whichever unversioned `node` alternative happens to be active.

The AMI value is resolved at plan time from the AWS public SSM parameter. The current parameter value, selected VPC/subnet, route table, key pair, and instance-type availability still require live read-only verification in the target account and region.

The backend installs the pinned `gunicorn_version` into the application virtual environment and starts `app:app` from `applications/backend`. The shared `requirements.txt` remains unchanged; pip is not upgraded implicitly during bootstrap.

Do not commit `terraform.tfvars`, credentials, private keys, or generated state. Confirm the subnet route table has `0.0.0.0/0` through an internet gateway; Terraform also checks this during planning.

## Safe initialization and validation

Run these commands from this directory only:

```powershell
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

`terraform init -backend=false` installs provider plugins without configuring a remote backend. It may create a local `.terraform` directory and lock file; do not copy either from another Task directory.

## Plan review

After setting local variables, create a plan for human review:

```powershell
terraform plan -out=task2-v2.tfplan
terraform show -no-color task2-v2.tfplan
```

Check the plan for exactly two EC2 instances, two new v2 security groups, the intended VPC/subnet, the intended key pair, and no references to Task 1 or legacy Task 2 resources. Apply only after explicit human approval:

```powershell
terraform apply task2-v2.tfplan
```

The apply command is intentionally not run as part of this implementation.

## Post-deployment verification

Review the Terraform outputs:

```powershell
terraform output
```

Confirm both instances are running and their system and instance status checks are healthy. From the backend instance or another authorized network location, check:

```bash
curl -i http://<backend-private-ip>:5000/api/health
```

From a client allowed by `client_cidr`, check:

```bash
curl -i http://<frontend-public-ip>:3000/
curl -i http://<frontend-public-ip>:3000/api/health
```

Open the frontend URL in a browser and submit a valid contact form. The frontend health response should include the Flask backend health response.

Inspect service state and logs on the instances:

```bash
sudo systemctl status terraform-assignment-part-2-v2-backend.service --no-pager
sudo systemctl status terraform-assignment-part-2-v2-frontend.service --no-pager
sudo journalctl -u terraform-assignment-part-2-v2-backend.service -n 100 --no-pager
sudo journalctl -u terraform-assignment-part-2-v2-frontend.service -n 100 --no-pager
```

Bootstrap logs are also written to:

```text
/var/log/terraform-assignment-part-2-v2-backend-bootstrap.log
/var/log/terraform-assignment-part-2-v2-frontend-bootstrap.log
```

## Cleanup and cost control

EC2, EBS, public IPv4, and related resources can incur charges. After the assignment, review the state and plan carefully, then obtain explicit approval before running:

```powershell
terraform plan -destroy
terraform destroy
```

Do not delete shared Task 1, Task 3, IAM, key-pair, or unrelated resources. Never use a state file from another Task directory.

## Security warnings

- Never open backend port 5000 to `0.0.0.0/0`.
- Keep SSH restricted to a trusted `/32` whenever possible.
- Do not put credentials, access keys, passwords, tokens, or private keys in Terraform files, user-data, screenshots, or Git.
- The source repository must be public HTTPS for this bootstrap design. A private repository requires a separately designed and approved secret-delivery mechanism.
- The public IPs and instance IDs in outputs are operational data; do not publish them unnecessarily.

## Screenshot checklist

Capture only after the relevant operation and redact account identifiers or secrets where applicable:

1. Terraform formatting, initialization, and validation.
2. Reviewed Terraform plan showing two instances and two v2 security groups.
3. Successful deployment and Terraform outputs.
4. Both instance IDs and running/status-check evidence.
5. Frontend page and successful form submission.
6. Backend health response from an authorized network location.
7. Frontend health response showing backend communication.
8. Git status showing intended files and no secrets or generated state.
