#!/usr/bin/env bash
set -euo pipefail

# ─── upload.sh ────────────────────────────────────────────────────────────────
# Upload certs and/or env files to VPS via SCP.
#
# Usage:
#   ./scripts/upload.sh <SSH_USER> <SSH_HOST> <APP_DIR> <what>
#   <what>: certs | env-staging | env-production | all
#
#   make upload-certs SSH_USER=root SSH_HOST=1.2.3.4
#   make upload-env-production SSH_USER=root SSH_HOST=1.2.3.4

SSH_USER="${1:?❌ Usage: upload.sh <SSH_USER> <SSH_HOST> <APP_DIR> <what>}"
SSH_HOST="${2:?❌ Usage: upload.sh <SSH_USER> <SSH_HOST> <APP_DIR> <what>}"
APP_DIR="${3:-/opt/app}"
WHAT="${4:-all}"
SSH_TARGET="${SSH_USER}@${SSH_HOST}"

upload_certs() {
    if [ ! -f "docker/traefik/certs/cert.pem" ]; then
        echo "❌ No cert found. Run: make setup-cf-cert"
        exit 1
    fi
    echo "📦 Uploading certs to ${SSH_TARGET}:${APP_DIR}/docker/traefik/certs/"
    ssh "${SSH_TARGET}" "mkdir -p ${APP_DIR}/docker/traefik/certs"
    scp -q docker/traefik/certs/cert.pem docker/traefik/certs/private.key \
        "${SSH_TARGET}:${APP_DIR}/docker/traefik/certs/"
    echo "✅ Certs uploaded"
}

upload_env() {
    local env_file=".env.${1}"
    if [ ! -f "$env_file" ]; then
        echo "❌ No ${env_file} found. Run: make init-env-${1}"
        exit 1
    fi
    echo "📦 Uploading ${env_file} to ${SSH_TARGET}:${APP_DIR}/"
    scp -q "$env_file" "${SSH_TARGET}:${APP_DIR}/${env_file}"
    echo "✅ ${env_file} uploaded"
}

case "$WHAT" in
    certs)
        upload_certs
        ;;
    env-staging)
        upload_env "staging"
        ;;
    env-production)
        upload_env "production"
        ;;
    all)
        upload_certs
        upload_env "staging" 2>/dev/null || echo "⚠️  .env.staging not found (skip)"
        upload_env "production" 2>/dev/null || echo "⚠️  .env.production not found (skip)"
        ;;
    *)
        echo "❌ Unknown: ${WHAT}. Use: certs | env-staging | env-production | all"
        exit 1
        ;;
esac
