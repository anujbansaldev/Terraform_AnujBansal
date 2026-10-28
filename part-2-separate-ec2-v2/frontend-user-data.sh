#!/bin/bash
set -Eeuo pipefail

LOG_FILE=/var/log/terraform-assignment-part-2-v2-frontend-bootstrap.log
exec > >(tee -a "$LOG_FILE") 2>&1
trap 'rc=$?; echo "[$(date --iso-8601=seconds)] frontend bootstrap failed at line $LINENO (exit $rc)"; exit $rc' ERR

echo "[$(date --iso-8601=seconds)] starting Task 2 v2 frontend bootstrap"

dnf install -y git nodejs22 nodejs22-npm

NODE_BIN=/usr/bin/node-22
NPM_BIN=/usr/bin/npm-22

test -x "$NODE_BIN"
test -x "$NPM_BIN"

if ! "$NODE_BIN" --version | grep -Eq '^v(18|19|20|21|22|23|24)\.'; then
  echo "The Amazon Linux repository did not provide a supported Node.js 18-24 runtime with built-in fetch support" >&2
  "$NODE_BIN" --version >&2
  exit 1
fi

APP_ROOT=/opt/terraform-assignment-part-2-v2
SOURCE_URL='${application_source_url}'
SOURCE_REF='${application_source_ref}'
BACKEND_PRIVATE_IP='${backend_private_ip}'

if [[ "$SOURCE_URL" != https://* ]]; then
  echo "SOURCE_URL must be a public HTTPS Git URL" >&2
  exit 1
fi

rm -rf "$APP_ROOT"
GIT_TERMINAL_PROMPT=0 git clone --depth=1 --branch "$SOURCE_REF" "$SOURCE_URL" "$APP_ROOT"

test -f "$APP_ROOT/applications/frontend/server.js"
test -f "$APP_ROOT/applications/frontend/package.json"
test -f "$APP_ROOT/applications/frontend/package-lock.json"

cd "$APP_ROOT/applications/frontend"
"$NPM_BIN" ci --omit=dev

chown -R ec2-user:ec2-user "$APP_ROOT"

cat >/etc/systemd/system/terraform-assignment-part-2-v2-frontend.service <<EOF
[Unit]
Description=Terraform assignment Task 2 v2 Express frontend
Wants=network-online.target
After=network-online.target

[Service]
User=ec2-user
WorkingDirectory=$APP_ROOT/applications/frontend
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=BACKEND_URL=http://$BACKEND_PRIVATE_IP:5000
ExecStart=/usr/bin/npm-22 start
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now terraform-assignment-part-2-v2-frontend.service
systemctl --no-pager --full status terraform-assignment-part-2-v2-frontend.service

echo "[$(date --iso-8601=seconds)] Task 2 v2 frontend bootstrap completed"
