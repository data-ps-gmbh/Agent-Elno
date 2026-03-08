#!/usr/bin/env bash
set -euo pipefail

# Agent-Elno — Standalone Uninstall Script
# Removes services, binaries, config, and data.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/data-ps-gmbh/Agent-Elno/main/remove-agent-elno.sh | sudo bash

INSTALL_DIR="/opt/dataps-ai"
SERVICE_USER="agent-elno"
SERVICES=(dataps-ai-api dataps-ai-app dataps-ai-mcp)

info()  { printf '\033[1;34m[agent-elno]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[agent-elno]\033[0m %s\n' "$1"; }
fail()  { printf '\033[1;31m[agent-elno]\033[0m %s\n' "$1" >&2; exit 1; }

[[ $EUID -eq 0 ]] || fail "This script must be run as root."

if [[ ! -d "$INSTALL_DIR" ]]; then
    info "Nothing to remove — ${INSTALL_DIR} does not exist."
    exit 0
fi

echo ""
warn "This will permanently remove Agent-Elno including all data and databases."
printf '\033[1;33m[?]\033[0m Type "yes" to confirm: '
read -r REPLY
[[ "$REPLY" == "yes" ]] || { info "Aborted."; exit 0; }
echo ""

# --- Stop and remove services ---

info "Stopping services..."
for svc in "${SERVICES[@]}"; do
    systemctl stop "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
    rm -f "/etc/systemd/system/${svc}.service"
done
systemctl daemon-reload

# --- Remove install directory ---

info "Removing ${INSTALL_DIR}..."
rm -rf "$INSTALL_DIR"

# --- Remove system user ---

if id -u "$SERVICE_USER" &>/dev/null; then
    info "Removing system user '${SERVICE_USER}'..."
    userdel "$SERVICE_USER" 2>/dev/null || warn "Could not remove user '${SERVICE_USER}'"
fi

echo ""
info "Agent-Elno has been completely removed."
echo ""
