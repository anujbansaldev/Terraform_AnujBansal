#!/bin/bash
set -Eeuo pipefail

LOG_FILE=/var/log/terraform-assignment-part-2-v2-backend-bootstrap.log
exec > >(tee -a "$LOG_FILE") 2>&1
trap 'rc=$?; echo "[$(date --iso-8601=seconds)] backend bootstrap failed at line $LINENO (exit $rc)"; exit $rc' ERR

echo "[$(date --iso-8601=seconds)] starting Task 2 v2 backend bootstrap"

dnf install -y git python3.11 python3.11-pip

APP_ROOT=/opt/terraform-assignment-part-2-v2
SOURCE_URL='${application_source_url}'
SOURCE_REF='${application_source_ref}'
GUNICORN_VERSION='${gunicorn_version}'

if [[ "$SOURCE_URL" != https://* ]]; then
  echo "SOURCE_URL must be a public HTTPS Git URL" >&2
  exit 1
fi

rm -rf "$APP_ROOT"
GIT_TERMINAL_PROMPT=0 git clone --depth=1 --branch "$SOURCE_REF" "$SOURCE_URL" "$APP_ROOT"

test -f "$APP_ROOT/applications/backend/app.py"
test -f "$APP_ROOT/applications/backend/requirements.txt"

python3.11 -m venv "$APP_ROOT/.venv"
"$APP_ROOT/.venv/bin/pip" install "gunicorn==$${GUNICORN_VERSION}"
"$APP_ROOT/.venv/bin/pip" install --requirement "$APP_ROOT/applications/backend/requirements.txt"

chown -R ec2-user:ec2-user "$APP_ROOT"

cat >/etc/systemd/system/terraform-assignment-part-2-v2-backend.service <<EOF
[Unit]
Description=Terraform assignment Task 2 v2 Flask backend
Wants=network-online.target
After=network-online.target

[Service]
User=ec2-user
WorkingDirectory=$APP_ROOT/applications/backend
Environment=FLASK_HOST=0.0.0.0
Environment=FLASK_PORT=5000
ExecStart=$APP_ROOT/.venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 --access-logfile - --error-logfile - app:app
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now terraform-assignment-part-2-v2-backend.service
systemctl --no-pager --full status terraform-assignment-part-2-v2-backend.service

echo "[$(date --iso-8601=seconds)] Task 2 v2 backend bootstrap completed"
