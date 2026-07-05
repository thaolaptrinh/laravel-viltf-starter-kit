#!/usr/bin/env bash
set -euo pipefail

# ─── setup-vps-login.sh ───────────────────────────────────────────────────────
# Configure GHCR login on VPS without leaking token in process list.
#
# Usage:
#   ./scripts/setup-vps-login.sh <SSH_USER> <SSH_HOST> <GHCR_PAT> <GH_USERNAME>
#   make setup-vps-login SSH_USER=root SSH_HOST=1.2.3.4 GHCR_PAT=xxx GH_USERNAME=user

SSH_USER="${1:?❌ Usage: setup-vps-login.sh <SSH_USER> <SSH_HOST> <GHCR_PAT> <GH_USERNAME>}"
SSH_HOST="${2:?❌ Usage: setup-vps-login.sh <SSH_USER> <SSH_HOST> <GHCR_PAT> <GH_USERNAME>}"
GHCR_PAT="${3:?❌ Usage: setup-vps-login.sh <SSH_USER> <SSH_HOST> <GHCR_PAT> <GH_USERNAME>}"
GH_USERNAME="${4:?❌ Usage: setup-vps-login.sh <SSH_USER> <SSH_HOST> <GHCR_PAT> <GH_USERNAME>}"
SSH_TARGET="${SSH_USER}@${SSH_HOST}"

echo "🔐 Configuring GHCR login on ${SSH_TARGET}..."

# Write token to temp file on VPS, use it for login, then delete.
# Token never appears in `ps aux` output.
echo "${GHCR_PAT}" | ssh "${SSH_TARGET}" '
    cat > /tmp/.ghcr_token
    docker login ghcr.io -u '"${GH_USERNAME}"' --password-stdin < /tmp/.ghcr_token
    rm -f /tmp/.ghcr_token
'

echo "✅ GHCR login configured on ${SSH_TARGET}"
