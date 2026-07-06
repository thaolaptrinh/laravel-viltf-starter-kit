#!/usr/bin/env bash
set -euo pipefail

# ─── init-env.sh ──────────────────────────────────────────────────────────────
# Run ON THE VPS to generate .env.production / .env.staging with auto secrets.
#
# Usage (on VPS):
#   cd /opt/app && ./scripts/init-env.sh production
#   cd /opt/app && ./scripts/init-env.sh staging
#
# What it does:
#   1. Copies .env.{env}.example → .env.{env}
#   2. Auto-generates: APP_KEY, REVERB_APP_KEY/SECRET, DB/REDIS passwords,
#      TRAEFIK_AUTH (bcrypt via htpasswd, auto-installs apache2-utils if missing)
#   3. Prompts for domain

ENV="${1:-production}"
ENV_FILE=".env.${ENV}"
ENV_EXAMPLE="${ENV_FILE}.example"

if [ ! -f "$ENV_EXAMPLE" ]; then
    echo "❌ Template not found: ${ENV_EXAMPLE}"
    echo "   Repo not cloned yet? Run on VPS after 'make setup-vps'."
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 Generating secrets for ${ENV} environment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Copy template if env doesn't exist. If exists: prompt (TTY) or auto-decide (non-TTY).
if [ -f "$ENV_FILE" ]; then
    if grep -q "CHANGE_ME" "$ENV_FILE" 2>/dev/null; then
        echo "⚠️  ${ENV_FILE} contains placeholder values — overwriting with fresh secrets."
    elif [ -t 0 ] && [ -t 1 ]; then
        # Interactive TTY — ask
        echo "⚠️  ${ENV_FILE} already exists."
        read -rp "   [O]verwrite or [s]kip? " choice
        case "${choice,,}" in
            o|overwrite) ;;
            *) echo "   ⏭ Skipped."; exit 0 ;;
        esac
    else
        # Non-TTY (e.g. bootstrap via SSH) — skip to preserve existing secrets
        echo "⚠️  ${ENV_FILE} already exists — skipping (run 'make init-env-production' interactively to regenerate)."
        exit 0
    fi
fi
cp "$ENV_EXAMPLE" "$ENV_FILE"

# ─── Secrets (pure openssl — no PHP/Docker required on VPS) ──────────────────
APP_KEY="base64:$(openssl rand -base64 32)"
REVERB_KEY=$(openssl rand -hex 16)
REVERB_SECRET=$(openssl rand -hex 32)
DB_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 24)
REDIS_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 24)

# ─── Domain (required, can be passed via APP_DOMAIN env for non-interactive) ─
if [ -z "${APP_DOMAIN:-}" ]; then
    read -rp "🌐 App domain (e.g., yourdomain.com): " APP_DOMAIN
fi
if [ -z "$APP_DOMAIN" ]; then
    echo "❌ Domain is required"
    exit 1
fi
echo "🌐 Domain: ${APP_DOMAIN}"

# ─── Traefik dashboard basic auth (bcrypt) ───────────────────────────────────
TRAEFIK_USER="${TRAEFIK_USER:-admin}"
TRAEFIK_PASS=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 16)
SKIP_TRAEFIK=false
if ! command -v htpasswd >/dev/null 2>&1; then
    echo "📦 Installing apache2-utils for htpasswd..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y apache2-utils >/dev/null
    else
        echo "⚠️  htpasswd not available — skip TRAEFIK_AUTH."
        SKIP_TRAEFIK=true
    fi
fi
if [ "$SKIP_TRAEFIK" = false ]; then
    TRAEFIK_AUTH=$(htpasswd -nbB "$TRAEFIK_USER" "$TRAEFIK_PASS" | sed 's/\$/$$/g')
else
    TRAEFIK_AUTH=""
fi

# ─── Write to env file ───────────────────────────────────────────────────────
sed -i \
    -e "s|APP_URL=.*|APP_URL=https://${APP_DOMAIN}|" \
    -e "s|APP_DOMAIN=.*|APP_DOMAIN=${APP_DOMAIN}|" \
    -e "s|APP_KEY=.*|APP_KEY=${APP_KEY}|" \
    -e "s|REVERB_APP_KEY=.*|REVERB_APP_KEY=${REVERB_KEY}|" \
    -e "s|REVERB_APP_SECRET=.*|REVERB_APP_SECRET=${REVERB_SECRET}|" \
    -e "s|REVERB_HOST=.*|REVERB_HOST=${APP_DOMAIN}|" \
    -e "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" \
    -e "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=${REDIS_PASS}|" \
    -e "s|^VITE_REVERB_HOST=.*|VITE_REVERB_HOST=\"${APP_DOMAIN}\"|" \
    "$ENV_FILE"

if [ -n "$TRAEFIK_AUTH" ]; then
    sed -i "s|TRAEFIK_AUTH=.*|TRAEFIK_AUTH=${TRAEFIK_AUTH}|" "$ENV_FILE"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "✅ ${ENV_FILE} ready"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Generated secrets (saved to ${ENV_FILE}, not shown again):"
echo "   APP_KEY            : ${APP_KEY}"
echo "   REVERB_APP_KEY     : ${REVERB_KEY}"
echo "   REVERB_APP_SECRET  : ${REVERB_SECRET}"
echo "   DB_PASSWORD        : ${DB_PASS}"
echo "   REDIS_PASSWORD     : ${REDIS_PASS}"
if [ -n "$TRAEFIK_AUTH" ]; then
    echo "   Traefik dashboard  : ${TRAEFIK_USER} / ${TRAEFIK_PASS}"
fi
echo ""
echo "Next steps:"
echo "   1. make setup-vps-dns SSH_USER=... SSH_HOST=... CF_API_TOKEN=... APP_DOMAIN=..."
echo "   2. make deploy-${ENV}"
echo "   3. After deploy: make migrate-${ENV}"
