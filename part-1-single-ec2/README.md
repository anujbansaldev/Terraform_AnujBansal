# Part 1: Single EC2 deployment

This module deploys the Flask backend and Express frontend to one Amazon Linux 2023 EC2 instance.

## Architecture

- Flask listens privately on `127.0.0.1:5000` for this deployment.
- Express listens on `0.0.0.0:3000` and proxies health/submission requests to Flask.
- SSH (`22/tcp`) is restricted to `trusted_ip_cidr`.
- Only the frontend port (`3000/tcp`) is public. Port `5000` is intentionally not in the security group.
- The SSM instance profile is an existing IAM dependency named by `ssm_instance_profile_name`; this module does not create or replace it.

## Terraform commands

Run these commands from `part-1-single-ec2`:

```powershell
terraform fmt -check
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Required variables include `ami_id`, `key_name`, `trusted_ip_cidr`, and `application_source_url`. The repository must be publicly readable when the instance bootstrap runs; the script disables interactive Git authentication.

## Bootstrap and services

The user-data script installs Git, Python 3.11, pip, Node.js and npm; clones the selected branch; verifies the application files; creates a Python virtual environment; runs `pip install` and `npm ci --omit=dev`; then configures and enables:

- `terraform-flask.service`
- `terraform-express.service`

Bootstrap output is appended to `/var/log/terraform-assignment-bootstrap.log`. The script is safe to rerun after access is restored and updates an existing clone instead of requiring an interactive shell.

## Verification

Run on the instance:

```bash
curl -i http://127.0.0.1:5000/api/health
curl -i http://127.0.0.1:3000/
curl -i http://127.0.0.1:3000/api/health
sudo systemctl status terraform-flask.service --no-pager
sudo systemctl status terraform-express.service --no-pager
sudo journalctl -u terraform-flask.service -n 100 --no-pager
sudo journalctl -u terraform-express.service -n 100 --no-pager
```

Externally, open `http://<instance-public-ip>:3000`. The Flask endpoint is intentionally not advertised as a public URL; the Terraform `backend_url` output is the instance-local URL.

## Troubleshooting

Cloud-init user-data runs on initial boot. Editing `user-data.sh` does not rerun it on an existing instance. After SSM is online, use an authenticated Session Manager shell or a controlled `AWS-RunShellScript` command to run the corrected script on the current instance. If SSM and SSH are both unavailable, use an AWS-supported recovery path such as EC2 Serial Console or a helper instance with the root volume attached; do not expose SSH globally.

The original failure was an interactive Git authentication prompt against a private repository. The repository is now public, and the corrected script uses a public HTTPS URL with `GIT_TERMINAL_PROMPT=0`.

## Current verification status

The existing instance `i-0c79da58b375925a5` is running and its EC2 system and instance status checks are `ok`. Its manually created SSM profile is associated and contains `AmazonSSMManagedInstanceCore`, but the instance was not yet present in `aws ssm describe-instance-information` at the time of the latest diagnosis. Application HTTP and systemd results therefore remain pending remote access and a controlled rerun.
