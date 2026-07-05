#!/usr/bin/env bash
set -euo pipefail

# ─── setup-vps.sh ─────────────────────────────────────────────────────────────
# Provision a fresh VPS with Docker + docker-rollout + project clone.
# Idempotent — safe to run multiple times.
#
# Usage:
#   make setup-vps SSH_USER=root SSH_HOST=1.2.3.4
#   make setup-vps  (interactive prompt)

GH_REPO="${GH_REPO:-thaolaptrinh/laravel-viltf}"
APP_DIR="${APP_DIR:-/opt/app}"

# Prompt for missing values
SSH_USER="${SSH_USER:-}"
if [ -z "$SSH_USER" ]; then
    read -rp "👤 SSH user (e.g., root): " SSH_USER
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

echo "🚀 Provisioning ${SSH_TARGET}..."
echo "   Repo: ${GH_REPO}"
echo "   App dir: ${APP_DIR}"
echo ""

# Run provisioning script on VPS via SSH (heredoc — clean, readable)
ssh "${SSH_TARGET}" 'bash -s' << PROVISION_SCRIPT
set -euo pipefail

echo "─── Docker ───"
if command -v docker &>/dev/null; then
    echo "✅ Docker already installed: \$(docker --version)"
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
echo "─── Project ───"
if [ -d "${APP_DIR}/.git" ]; then
    echo "📦 Updating existing repo..."
    cd "${APP_DIR}"
    git pull --ff-only
else
    echo "📦 Cloning repo..."
    mkdir -p "$(dirname "${APP_DIR}")"
    git clone "https://github.com/${GH_REPO}.git" "${APP_DIR}"
fi

echo ""
echo "─── Swap (if < 8GB RAM) ───"
TOTAL_RAM=\$(free -m | awk '/^Mem:/{print \$2}')
if [ "\$TOTAL_RAM" -lt 6144 ] && [ ! -f /swapfile ]; then
    echo "📦 Creating 2GB swap..."
    dd if=/dev/zero of=/swapfile bs=1M count=2048
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo "✅ Swap enabled (2GB)"
else
    echo "✅ Swap not needed (RAM ≥ 6GB or swap already exists)"
fi

echo ""
echo "════════════════════════════════════════"
echo "✅ VPS ready: ${SSH_TARGET}"
echo "════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. make setup-vps-login"
echo "  2. make upload-certs"
echo "  3. make upload-env-production"
echo "  4. make deploy-production"
PROVISION_SCRIPT

echo ""
echo "✅ Provisioning complete."
