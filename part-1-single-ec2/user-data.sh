#!/bin/bash
set -euo pipefail

# Amazon Linux 2023 packages. The source repository is provided by Terraform.
dnf update -y
dnf install -y git python3.11 python3.11-pip nodejs npm

APP_ROOT=/opt/terraform-assignment
rm -rf "$APP_ROOT"
git clone --branch '${application_source_ref}' '${application_source_url}' "$APP_ROOT"

python3.11 -m venv "$APP_ROOT/.venv"
"$APP_ROOT/.venv/bin/pip" install --upgrade pip
"$APP_ROOT/.venv/bin/pip" install -r "$APP_ROOT/applications/backend/requirements.txt"

cd "$APP_ROOT/applications/frontend"
npm install --omit=dev

cat >/etc/systemd/system/terraform-flask.service <<EOF
[Unit]
After=network-online.target
[Service]
WorkingDirectory=$APP_ROOT/applications/backend
ExecStart=$APP_ROOT/.venv/bin/python app.py
Restart=always
[Install]
WantedBy=multi-user.target
EOF

cat >/etc/systemd/system/terraform-express.service <<EOF
[Unit]
After=network-online.target terraform-flask.service
Requires=terraform-flask.service
[Service]
WorkingDirectory=$APP_ROOT/applications/frontend
Environment=BACKEND_URL=http://127.0.0.1:5000
ExecStart=/usr/bin/npm start
Restart=always
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now terraform-flask.service terraform-express.service
