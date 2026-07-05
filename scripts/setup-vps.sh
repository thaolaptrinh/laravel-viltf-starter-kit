#!/usr/bin/env bash
set -euo pipefail

# ─── setup-vps.sh ─────────────────────────────────────────────────────────────
# Provision a fresh VPS with Docker + docker-rollout + project clone.
# Idempotent — safe to run multiple times.
#
# Usage:
#   ./scripts/setup-vps.sh <SSH_USER> <SSH_HOST> [GH_REPO] [APP_DIR]
#   make setup-vps SSH_USER=root SSH_HOST=1.2.3.4

SSH_USER="${1:?❌ Usage: setup-vps.sh <SSH_USER> <SSH_HOST> [GH_REPO] [APP_DIR]}"
SSH_HOST="${2:?❌ Usage: setup-vps.sh <SSH_USER> <SSH_HOST> [GH_REPO] [APP_DIR]}"
GH_REPO="${3:-thaolaptrinh/laravel-viltf}"
APP_DIR="${4:-/opt/app}"
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
echo "  1. make setup-vps-login SSH_USER=${SSH_USER} SSH_HOST=${SSH_HOST} GHCR_PAT=xxx GH_USERNAME=xxx"
echo "  2. make upload-certs SSH_USER=${SSH_USER} SSH_HOST=${SSH_HOST}"
echo "  3. make upload-env-production SSH_USER=${SSH_USER} SSH_HOST=${SSH_HOST}"
echo "  4. make deploy-production SSH_PRODUCTION=${SSH_TARGET}"
PROVISION_SCRIPT

echo ""
echo "✅ Provisioning complete."
