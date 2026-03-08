#!/usr/bin/env bash
set -euo pipefail

# Agent-Elno — Download latest release and run install/update
# The installer auto-detects whether this is a fresh install or an update.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/data-ps-gmbh/Agent-Elno/main/get-agent-elno.sh | sudo bash

REPO="data-ps-gmbh/Agent-Elno"
RUNTIME="linux-x64"
TMPDIR="$(mktemp -d)"

info()  { printf '\033[1;34m[agent-elno]\033[0m %s\n' "$1"; }
fail()  { printf '\033[1;31m[agent-elno]\033[0m %s\n' "$1" >&2; exit 1; }
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

# --- Detect latest release ---

info "Fetching latest release from GitHub..."
LATEST=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"tag_name":\s*"([^"]+)".*/\1/')

if [[ -z "$LATEST" ]]; then
    fail "Could not determine latest release. Check https://github.com/${REPO}/releases"
fi

# Strip leading 'v' for the filename pattern
VERSION="${LATEST#v}"
ARTIFACT="dataps-ai-${VERSION}-${RUNTIME}"
URL="https://github.com/${REPO}/releases/download/${LATEST}/${ARTIFACT}.tar.gz"

info "Latest release: ${LATEST}"

# --- Download ---

info "Downloading ${ARTIFACT}.tar.gz ..."
curl -fSL -o "${TMPDIR}/${ARTIFACT}.tar.gz" "$URL" || fail "Download failed. Does the release asset exist?\n  ${URL}"

# --- Extract ---

info "Extracting..."
tar -xzf "${TMPDIR}/${ARTIFACT}.tar.gz" -C "$TMPDIR"

EXTRACTED="${TMPDIR}/${ARTIFACT}"
if [[ ! -d "$EXTRACTED" ]]; then
    fail "Expected directory ${ARTIFACT} not found after extraction."
fi

# --- Run installer (auto-detects install vs update) ---

info "Running installer..."
bash "${EXTRACTED}/scripts/install.sh"

info "Done!"
