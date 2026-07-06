#!/usr/bin/env bash
set -euo pipefail

# ─── setup-vps-login.sh ───────────────────────────────────────────────────────
# Configure GHCR login on VPS without leaking token in process list.
#
# Usage:
#   make setup-vps-login SSH_USER=root SSH_HOST=1.2.3.4
#   make setup-vps-login  (interactive prompt)

GH_USERNAME="${GH_USERNAME:-}"
if [ -z "$GH_USERNAME" ]; then
    read -rp "👤 GitHub username: " GH_USERNAME
    echo ""
    [ -z "$GH_USERNAME" ] && { echo "❌ Username required"; exit 1; }
fi

GHCR_PAT="${GHCR_PAT:-}"
if [ -z "$GHCR_PAT" ]; then
    read -rsp "🔑 GHCR PAT (write:packages scope, input hidden): " GHCR_PAT
    echo ""
    [ -z "$GHCR_PAT" ] && { echo "❌ Token required"; exit 1; }
fi

SSH_USER="${SSH_USER:-}"
if [ -z "$SSH_USER" ]; then
    read -rp "👤 SSH user: " SSH_USER
    echo ""
    [ -z "$SSH_USER" ] && { echo "❌ SSH user required"; exit 1; }
fi

SSH_HOST="${SSH_HOST:-}"
if [ -z "$SSH_HOST" ]; then
    read -rp "🌐 VPS IP or hostname: " SSH_HOST
    echo ""
    [ -z "$SSH_HOST" ] && { echo "❌ SSH host required"; exit 1; }
fi

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
