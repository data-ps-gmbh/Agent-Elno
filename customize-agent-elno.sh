#!/usr/bin/env bash
set -euo pipefail

# ===========================================================================
# Agent-Elno — non-interactive install / update template
# ===========================================================================
# Copy this script, edit the CONFIG block below, then run it as root.
#   sudo bash customize-agent-elno.sh
#
# It downloads the latest GitHub release and runs the bundled installer with
# your config pre-filled — no prompts.
#
# Re-run it any time:
#   - First run: fresh install with your config.
#   - Subsequent runs: detected as an update — skips the wizard, replaces
#     binaries, preserves data and config. The CONFIG block is ignored on
#     update, so you can leave it as-is.
#
# Tip: schedule this as a nightly cron job (e.g. 04:00) for auto-updates.
#   0 4 * * * /usr/local/bin/customize-agent-elno.sh >> /var/log/agent-elno-update.log 2>&1
# ===========================================================================

# ---------------------------------------------------------------------------
# CONFIG — edit these values, then save and run
# ---------------------------------------------------------------------------

# Service ports (defaults shown). Change if these collide on your host.
export INSTALL_API_PORT="5100"
export INSTALL_APP_PORT="5200"

# Install the standalone MCP server (VS Code Copilot integration)?
# y = yes (also exposes INSTALL_MCP_PORT below)
# n = no
export INSTALL_MCP="y"
export INSTALL_MCP_PORT="5300"

# LLM server — any OpenAI-compatible endpoint (Ollama, LiteLLM, OpenAI, …)
# Leave INSTALL_SERVER_API_KEY empty for local instances without auth.
export INSTALL_SERVER_NAME="My LLM Server"
export INSTALL_SERVER_URL="http://your-llm-host:4000"
export INSTALL_SERVER_API_KEY=""

# Models — must exist on the LLM server above.
# Embedding model is optional; leave empty to skip semantic memory search.
export INSTALL_MODEL_DEFAULT="your-default-model"
export INSTALL_MODEL_EMBEDDING="nomic-embed-text"

# Public URLs — what external clients (mobile app, QR codes) will use.
# If you put a reverse proxy in front, set the HTTPS URLs here.
export INSTALL_PUBLIC_URL_API="http://your-server-ip:5100"
export INSTALL_PUBLIC_URL_APP="http://your-server-ip:5200"

# Config mode:
#   i = import once (bundled config imported on first start, manage via UI afterwards)
#   f = file       (watch local config directory, re-sync every 5 min)
#   g = git        (sync from a Git repository every 5 min — set INSTALL_CONFIG_REPO_URL)
export INSTALL_CONFIG_MODE="i"
# export INSTALL_CONFIG_REPO_URL="https://github.com/you/my-dataps-config.git"

# ---------------------------------------------------------------------------
# Below this line: download + install. You shouldn't need to edit anything.
# ---------------------------------------------------------------------------

REPO="data-ps-gmbh/Agent-Elno"
RUNTIME="linux-x64"
TMPDIR="$(mktemp -d)"

info()  { printf '\033[1;34m[agent-elno]\033[0m %s\n' "$1"; }
fail()  { printf '\033[1;31m[agent-elno]\033[0m %s\n' "$1" >&2; exit 1; }
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

[[ $EUID -eq 0 ]] || fail "This script must be run as root (try: sudo bash $0)."

info "Fetching latest release from GitHub..."
LATEST=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"tag_name"' | sed -E 's/.*"tag_name":\s*"([^"]+)".*/\1/')
[[ -n "$LATEST" ]] || fail "Could not determine latest release. Check https://github.com/${REPO}/releases"

VERSION="${LATEST#v}"
ARTIFACT="dataps-ai-${VERSION}-${RUNTIME}"
URL="https://github.com/${REPO}/releases/download/${LATEST}/${ARTIFACT}.tar.gz"

info "Latest release: ${LATEST}"
info "Downloading ${ARTIFACT}.tar.gz ..."
curl -fSL -o "${TMPDIR}/${ARTIFACT}.tar.gz" "$URL" \
    || fail "Download failed. Does the release asset exist?\n  ${URL}"

info "Extracting..."
tar -xzf "${TMPDIR}/${ARTIFACT}.tar.gz" -C "$TMPDIR"
EXTRACTED="${TMPDIR}/${ARTIFACT}"
[[ -d "$EXTRACTED" ]] || fail "Expected directory ${ARTIFACT} not found after extraction."

info "Running installer (non-interactive — using INSTALL_* env vars)..."
bash "${EXTRACTED}/scripts/install.sh"

info "Done!"
