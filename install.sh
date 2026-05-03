#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="fastapi-hello"
PORT="${PORT:-8080}"

echo "Building..."
nix build .#default --no-link
STORE_PATH=$(nix path-info .#default)

echo "Installing systemd service..."
sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF
[Unit]
Description=Fast API Hello World
After=network.target

[Service]
ExecStart=${STORE_PATH}/bin/${SERVICE_NAME}
Restart=on-failure
RestartSec=5
DynamicUser=true
ProtectHome=true
ProtectSystem=strict
NoNewPrivileges=true
Environment=PORT=${PORT}

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}
sudo systemctl restart ${SERVICE_NAME}

echo "Done. Status:"
systemctl status ${SERVICE_NAME} --no-pager
