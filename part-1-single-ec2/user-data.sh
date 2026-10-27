#!/bin/bash
set -Eeuo pipefail

LOG_FILE=/var/log/terraform-assignment-bootstrap.log
exec > >(tee -a "$LOG_FILE") 2>&1
trap 'rc=$?; echo "[$(date --iso-8601=seconds)] bootstrap failed at line $LINENO (exit $rc)"; exit $rc' ERR

echo "[$(date --iso-8601=seconds)] starting Part 1 bootstrap"

dnf install -y git python3.11 python3.11-pip nodejs npm

APP_ROOT=/opt/terraform-assignment
SOURCE_URL='${application_source_url}'
SOURCE_REF='${application_source_ref}'

if [[ "$SOURCE_URL" != https://* ]]; then
  echo "SOURCE_URL must be a public HTTPS Git URL" >&2
  exit 1
fi

if [[ -d "$APP_ROOT/.git" ]]; then
  git -C "$APP_ROOT" remote set-url origin "$SOURCE_URL"
  GIT_TERMINAL_PROMPT=0 git -C "$APP_ROOT" fetch --depth=1 origin "$SOURCE_REF"
  git -C "$APP_ROOT" checkout --force "$SOURCE_REF"
  git -C "$APP_ROOT" reset --hard "origin/$SOURCE_REF"
else
  rm -rf "$APP_ROOT"
  GIT_TERMINAL_PROMPT=0 git clone --depth=1 --branch "$SOURCE_REF" "$SOURCE_URL" "$APP_ROOT"
fi

test -f "$APP_ROOT/applications/backend/app.py"
test -f "$APP_ROOT/applications/backend/requirements.txt"
test -f "$APP_ROOT/applications/frontend/server.js"
test -f "$APP_ROOT/applications/frontend/package.json"
test -f "$APP_ROOT/applications/frontend/package-lock.json"

python3.11 -m venv "$APP_ROOT/.venv"
"$APP_ROOT/.venv/bin/python" -m pip install --upgrade pip
"$APP_ROOT/.venv/bin/pip" install --requirement "$APP_ROOT/applications/backend/requirements.txt"

cd "$APP_ROOT/applications/frontend"
npm ci --omit=dev

chown -R ec2-user:ec2-user "$APP_ROOT"

cat >/etc/systemd/system/terraform-flask.service <<EOF
[Unit]
Description=Terraform assignment Flask backend
Wants=network-online.target
After=network-online.target

[Service]
User=ec2-user
WorkingDirectory=$APP_ROOT/applications/backend
Environment=FLASK_HOST=127.0.0.1
Environment=FLASK_PORT=5000
ExecStart=$APP_ROOT/.venv/bin/python app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat >/etc/systemd/system/terraform-express.service <<EOF
[Unit]
Description=Terraform assignment Express frontend
Wants=network-online.target
After=network-online.target terraform-flask.service
Requires=terraform-flask.service

[Service]
User=ec2-user
WorkingDirectory=$APP_ROOT/applications/frontend
Environment=NODE_ENV=production
Environment=BACKEND_URL=http://127.0.0.1:5000
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable terraform-flask.service terraform-express.service
systemctl restart terraform-flask.service terraform-express.service
systemctl --no-pager --full status terraform-flask.service terraform-express.service

echo "[$(date --iso-8601=seconds)] bootstrap completed"
