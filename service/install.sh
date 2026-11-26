#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

sudo install -m 0755 \
    "$SCRIPT_DIR/setup/killswitch.sh" \
    /usr/local/sbin/killswitch.sh

sudo install -m 0644 \
    "$SCRIPT_DIR/service/killswitch.service" \
    /etc/systemd/system/killswitch.service

sudo systemctl daemon-reload
sudo systemctl enable killswitch.service
sudo systemctl restart killswitch.service

echo "Kill Switch service installed and started"