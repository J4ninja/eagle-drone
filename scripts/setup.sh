#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVICE_NAME="gstreamer-qgc.service"
SERVICE_SRC="$REPO_ROOT/service/$SERVICE_NAME"
START_SCRIPT_SRC="$REPO_ROOT/scripts/start-gstreamer.sh"
SERVICE_DEST="/etc/systemd/system/$SERVICE_NAME"
START_SCRIPT_DEST="/home/robot/eagle-drone/start-gstreamer.sh"

if [[ $EUID -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

install -D -m 0644 "$SERVICE_SRC" "$SERVICE_DEST"
install -D -m 0755 "$START_SCRIPT_SRC" "$START_SCRIPT_DEST"

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"

echo "Installed $SERVICE_NAME to systemd."
echo "Start script installed to $START_SCRIPT_DEST."