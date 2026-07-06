#!/usr/bin/env bash
set -euo pipefail

# ─── bootstrap-production.sh ──────────────────────────────────────────────────────
# Idempotent VPS deployment orchestrator. Each step detects existing state and skips.
# Run AFTER `make setup-vps`.

prompt() {
    local var="$1" msg="$2" cached="${3:-}"
    if [ -z "${!var:-}" ] && [ -n "$cached" ]; then
        printf '%s [%s]: ' "$msg" "$cached" >&2
        local input; read -r input
        eval "${var}=\"\${input:-\$cached}\""
    elif [ -z "${!var:-}" ]; then
        printf '%s: ' "$msg" >&2
        local input; read -r input
        eval "${var}=\"\$input\""
    fi
    [ -n "${!var}" ] || { echo "❌ ${var} required"; exit 1; }
}

prompt_secret() {
    local var="$1" msg="$2" cached="${3:-}"
    if [ -z "${!var:-}" ] && [ -n "$cached" ]; then
        printf '%s [cached]: ' "$msg" >&2
        local input; read -rs input; echo >&2
        eval "${var}=\"\${input:-\$cached}\""
    elif [ -z "${!var:-}" ]; then
        printf '%s (hidden): ' "$msg" >&2
        local input; read -rs input; echo >&2
        eval "${var}=\"\$input\""
    fi
    [ -n "${!var}" ] || { echo "❌ ${var} required"; exit 1; }
}

prompt SSH_USER    "SSH user"          "$SSH_USER"
prompt SSH_HOST    "VPS IP"             "$SSH_HOST"
prompt APP_DOMAIN  "App domain"        "$APP_DOMAIN"
prompt GH_USERNAME "GitHub username"   "$GH_USERNAME"
prompt_secret GHCR_PAT     "GHCR PAT"                     "$GHCR_PAT"
prompt_secret CF_API_TOKEN "CF API token (Zone:Edit)"    "$CF_API_TOKEN"
CF_CA_TOKEN="${CF_CA_TOKEN:-$CF_API_TOKEN}"

# Cache tokens for re-runs so you don't type them again
TOKEN_CACHE="$HOME/.cache/laravel-viltf/bootstrap-tokens"
mkdir -p "$(dirname "$TOKEN_CACHE")"
cat > "$TOKEN_CACHE" << EOF
GHCR_PAT=${GHCR_PAT}
CF_API_TOKEN=${CF_API_TOKEN}
CF_CA_TOKEN=${CF_CA_TOKEN}
EOF
chmod 600 "$TOKEN_CACHE"

APP_DIR="${APP_DIR:-/opt/app}"
IMAGE="${IMAGE:-ghcr.io/thaolaptrinh/laravel-viltf}"

SSH_TARGET="${SSH_USER}@${SSH_HOST}"
KEY_FILE="$HOME/.ssh/${KEY_NAME:-laravel-viltf}"
SSH_CMD="ssh -i ${KEY_FILE} -o BatchMode=yes"
SCP_CMD="scp -i ${KEY_FILE} -o BatchMode=yes"
STEP=0
total=7

skip() { echo "   ⏭  Already done — skipping"; }
check_done() { local var="$1"; [ "${!var:-false}" = "true" ]; }

echo "🚀 Bootstrap → ${SSH_TARGET}"
echo "   Domain: ${APP_DOMAIN}"
echo "   App dir: ${APP_DIR}"
echo ""

# ─── 1/7 Upload config ──────────────────────────────────────────────────────
echo "─── $((++STEP))/${total} Upload config ───"
${SCP_CMD} compose.yaml compose.prod.yaml "${SSH_TARGET}:${APP_DIR}/"
${SCP_CMD} -r docker/app docker/postgres "${SSH_TARGET}:${APP_DIR}/docker/"
${SCP_CMD} docker/traefik/traefik.yml docker/traefik/dynamic.yml "${SSH_TARGET}:${APP_DIR}/docker/traefik/"
${SCP_CMD} .env.production.example "${SSH_TARGET}:${APP_DIR}/"
${SCP_CMD} scripts/init-env.sh scripts/setup-cf-cert.sh scripts/setup-cf-dns.sh "${SSH_TARGET}:${APP_DIR}/scripts/"
${SSH_CMD} "${SSH_TARGET}" "mkdir -p ${APP_DIR}/docker/traefik/certs ${APP_DIR}/docker/postgres ${APP_DIR}/scripts && chmod +x ${APP_DIR}/scripts/*.sh"
echo "   ✅ Uploaded"
echo ""

# ─── 2/7 GHCR login ─────────────────────────────────────────────────────────
echo "─── $((++STEP))/${total} GHCR login ───"
if ${SSH_CMD} "${SSH_TARGET}" "docker pull ghcr.io/thaolaptrinh/laravel-viltf:latest --quiet 2>/dev/null" 2>/dev/null; then
    skip
else
    ${SSH_CMD} "${SSH_TARGET}" "echo '${GHCR_PAT}' | docker login ghcr.io -u '${GH_USERNAME}' --password-stdin" 2>&1 | grep -v "Login Succeeded" || true
    echo "   ✅ Logged in"
fi
echo ""

# ─── 3/7 CF DNS + SSL ──────────────────────────────────────────────────────
echo "─── $((++STEP))/${total} CF DNS + SSL ───"
# Skip if both A records already point to this VPS IP
VPS_IP=$(${SSH_CMD} "${SSH_TARGET}" "curl -sf https://ifconfig.me 2>/dev/null || curl -sf https://api.ipify.org 2>/dev/null" 2>/dev/null || echo "")
if [ -n "$VPS_IP" ]; then
    DNS_A=$(dig +short "${APP_DOMAIN}" 2>/dev/null | head -1)
    DNS_TRAEFIK=$(dig +short "traefik.${APP_DOMAIN}" 2>/dev/null | head -1)
    if [ "$DNS_A" = "$VPS_IP" ] && [ "$DNS_TRAEFIK" = "$VPS_IP" ]; then
        skip
    else
        ${SSH_CMD} "${SSH_TARGET}" "cd ${APP_DIR} && APP_DOMAIN='${APP_DOMAIN}' CF_API_TOKEN='${CF_API_TOKEN}' ./scripts/setup-cf-dns.sh"
    fi
else
    ${SSH_CMD} "${SSH_TARGET}" "cd ${APP_DIR} && APP_DOMAIN='${APP_DOMAIN}' CF_API_TOKEN='${CF_API_TOKEN}' ./scripts/setup-cf-dns.sh"
fi
echo ""

# ─── 4/7 CF Origin Cert ────────────────────────────────────────────────────
echo "─── $((++STEP))/${total} CF Origin Cert ───"
CERT_EXISTS=$(${SSH_CMD} "${SSH_TARGET}" "test -f ${APP_DIR}/docker/traefik/certs/cert.pem && test -f ${APP_DIR}/docker/traefik/certs/private.key && echo true || echo false" 2>/dev/null)
if [ "$CERT_EXISTS" = "true" ]; then
    skip
else
    ${SSH_CMD} "${SSH_TARGET}" "cd ${APP_DIR} && APP_DOMAIN='${APP_DOMAIN}' CF_API_TOKEN='${CF_CA_TOKEN}' ./scripts/setup-cf-cert.sh"
fi
echo ""

# ─── 5/7 Generate .env.production ───────────────────────────────────────────
echo "─── $((++STEP))/${total} Generate .env.production ───"
ENV_EXISTS=$(${SSH_CMD} "${SSH_TARGET}" "test -f ${APP_DIR}/.env.production && grep -vq CHANGE_ME ${APP_DIR}/.env.production && echo true || echo false" 2>/dev/null)
if [ "$ENV_EXISTS" = "true" ]; then
    skip
else
    ${SSH_CMD} "${SSH_TARGET}" "cd ${APP_DIR} && rm -f .env.production && APP_DOMAIN='${APP_DOMAIN}' ./scripts/init-env.sh production"
fi
echo ""

# ─── 6/7 Deploy ────────────────────────────────────────────────────────────
echo "─── $((++STEP))/${total} Deploy ───"
# Compose variable substitution (${APP_DOMAIN}) reads from shell env, not env_file.
# env_file provides variables to the CONTAINER, but compose interpolation happens
# at launch time in the shell context. So we must export APP_DOMAIN.
${SSH_CMD} "${SSH_TARGET}" "
    cd ${APP_DIR} && \
    APP_DOMAIN='${APP_DOMAIN}' COMPOSE_PROFILES=production docker compose -f compose.yaml -f compose.prod.yaml pull && \
    APP_DOMAIN='${APP_DOMAIN}' COMPOSE_PROFILES=production docker compose -f compose.yaml -f compose.prod.yaml up -d --remove-orphans
"
echo ""

# ─── 7/7 Migrate ────────────────────────────────────────────────────────────
echo "─── $((STEP))/${total} Migrate DB ───"
# Wait briefly for app container to stabilise after deploy
sleep 5
${SSH_CMD} "${SSH_TARGET}" "
    cd ${APP_DIR} && \
    APP_DOMAIN='${APP_DOMAIN}' COMPOSE_PROFILES=production docker compose -f compose.yaml -f compose.prod.yaml exec -T app php artisan migrate --seed --force
"
echo ""

echo "════════════════════════════════════════"
echo "✅ Deployed → https://${APP_DOMAIN}"
echo "════════════════════════════════════════"
echo ""
echo "Verify:  curl -fk https://${APP_DOMAIN}/up"
echo "Deploy:  make deploy-production"
