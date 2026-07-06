#!/usr/bin/env bash
set -euo pipefail

# ─── setup-vps.sh ─────────────────────────────────────────────────────────────
# Provision a fresh VPS: SSH key → Docker + docker-rollout + UFW + storage.
# Asks for password ONCE (during ssh-copy-id), then key auth everywhere.
# Idempotent — safe to run multiple times.
#
# Usage:
#   make setup-vps SSH_USER=root SSH_HOST=1.2.3.4

APP_DIR="${APP_DIR:-/opt/app}"

SSH_USER="${SSH_USER:-}"
[ -z "$SSH_USER" ] && read -rp "👤 SSH user (e.g., root): " SSH_USER
[ -z "$SSH_USER" ] && { echo "❌ SSH user required"; exit 1; }

SSH_HOST="${SSH_HOST:-}"
[ -z "$SSH_HOST" ] && read -rp "🌐 VPS IP or hostname: " SSH_HOST
[ -z "$SSH_HOST" ] && { echo "❌ SSH host required"; exit 1; }

SSH_TARGET="${SSH_USER}@${SSH_HOST}"
KEY_NAME="${KEY_NAME:-laravel-viltf}"
KEY_FILE="$HOME/.ssh/${KEY_NAME}"
SSH_CMD="ssh -i ${KEY_FILE} -o BatchMode=yes"

echo "🚀 Provisioning ${SSH_TARGET}..."
echo "   App dir: ${APP_DIR}"
echo ""

# ─── 1. SSH key FIRST — one password prompt only ─────────────────────────────
echo "→ Setting up SSH key..."
if [ ! -f "${KEY_FILE}" ]; then
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -N "" -C "${SSH_TARGET}" -f "${KEY_FILE}" >/dev/null
    chmod 600 "${KEY_FILE}"
    echo "   Generated: ${KEY_FILE}"
else
    echo "   Reusing: ${KEY_FILE}"
fi

# Skip ssh-copy-id if key auth already works (idempotent re-runs)
if ${SSH_CMD} "${SSH_TARGET}" 'true' 2>/dev/null; then
    echo "   Key auth already works — skipping ssh-copy-id"
else
ssh-copy-id -i "${KEY_FILE}" -o PubkeyAuthentication=no "${SSH_TARGET}" >/dev/null 2>&1
echo "   Pubkey pushed to ${SSH_TARGET}"

# Register SSH config alias so `ssh laravel-viltf` uses this key automatically.
# Also maps the IP so `ssh root@1.2.3.4` works with key too.
CONFIG_FILE="$HOME/.ssh/config"
touch "$CONFIG_FILE" && chmod 600 "$CONFIG_FILE"
ALIAS="${SSH_ALIAS:-laravel-viltf}"
python3 - "$CONFIG_FILE" "${SSH_USER}" "${SSH_HOST}" "${KEY_FILE}" "${ALIAS}" << 'CONFIGPY'
import re, sys
config_path, user, host, keypath, alias = sys.argv[1:6]
with open(config_path) as f:
    content = f.read()
# Drop stale blocks for this alias and host IP
pattern = re.compile(r'^Host\s+(' + re.escape(alias) + r'|' + re.escape(host) + r')\b.*?(?=\nHost\s|\Z)', re.S | re.M)
content = pattern.sub('', content).rstrip() + '\n'
block = f"\nHost {alias} {host}\n    HostName {host}\n    User {user}\n    IdentityFile {keypath}\n    IdentitiesOnly yes\n"
with open(config_path, 'w') as f:
    f.write(content + block)
print(f"   SSH: {alias} → {user}@{host} (key: {keypath})")
CONFIGPY
echo "   $ ssh ${ALIAS}   # or: ssh ${SSH_USER}@${SSH_HOST}"
fi
echo ""

# ─── 2. Provision (key auth, no password) ────────────────────────────────────
${SSH_CMD} "${SSH_TARGET}" 'bash -s' << 'PROVISION_SCRIPT'
set -euo pipefail

echo "─── Docker ───"
if command -v docker &>/dev/null; then
    echo "✅ Docker already installed: $(docker --version)"
else
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    echo "✅ Docker installed"
fi

echo ""
echo "─── docker-rollout ───"
if [ -f ~/.docker/cli-plugins/docker-rollout ]; then
    echo "✅ docker-rollout already installed"
else
    echo "📦 Installing docker-rollout..."
    mkdir -p ~/.docker/cli-plugins
    curl -fsSL https://raw.githubusercontent.com/wowu/docker-rollout/master/docker-rollout \
        -o ~/.docker/cli-plugins/docker-rollout
    chmod +x ~/.docker/cli-plugins/docker-rollout
    echo "✅ docker-rollout installed"
fi

echo ""
echo "─── Firewall (UFW) ───"
if ! command -v ufw &>/dev/null; then
    echo "📦 Installing UFW..."
    apt-get update -qq && apt-get install -y -qq ufw || true
fi
if command -v ufw &>/dev/null; then
    ufw --force reset >/dev/null
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 443/udp
    ufw --force enable
    echo "✅ UFW active (allow 22, 80, 443)"
else
    echo "⚠️  UFW not available — open 22/80/443 manually"
fi
PROVISION_SCRIPT

# ─── 3. Storage dir (key auth, no password) ──────────────────────────────────
echo ""
echo "─── Storage ───"
${SSH_CMD} "${SSH_TARGET}" "
    mkdir -p ${APP_DIR}/storage/app/private ${APP_DIR}/storage/app/public \
             ${APP_DIR}/storage/framework/cache/data \
             ${APP_DIR}/storage/framework/sessions \
             ${APP_DIR}/storage/framework/views \
             ${APP_DIR}/storage/logs \
             ${APP_DIR}/bootstrap/cache
    chown -R 1000:1000 ${APP_DIR}/storage ${APP_DIR}/bootstrap/cache
    chmod -R u+rwX ${APP_DIR}/storage ${APP_DIR}/bootstrap/cache
"
echo "✅ ${APP_DIR}/storage ready (1000:1000)"

echo ""
echo "════════════════════════════════════════"
echo "✅ VPS ready"
echo "════════════════════════════════════════"
echo ""
echo "Next: bootstrap production (upload config + cert + dns + env + deploy)"
echo "  make bootstrap-production \\"
echo "    SSH_USER=${SSH_USER} SSH_HOST=${SSH_HOST} \\"
echo "    APP_DOMAIN=yourdomain.com \\"
echo "    GHCR_PAT=xxx GH_USERNAME=xxx \\"
echo "    CF_API_TOKEN=xxx [CF_CA_TOKEN=xxx]"
