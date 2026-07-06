#!/usr/bin/env bash
set -euo pipefail

# ─── init-env.sh ──────────────────────────────────────────────────────────────
# Run ON THE VPS to generate .env.production with auto-generated secrets.
#
# Usage (on VPS):
#   cd /opt/app && ./scripts/init-env.sh production
#   cd /opt/app && ./scripts/init-env.sh staging
#
# What it does:
#   1. Copies .env.{env}.example → .env.{env}
#   2. Auto-generates: APP_KEY, REVERB_APP_KEY, REVERB_APP_SECRET, TRAEFIK_AUTH
#   3. Prompts for: DB_PASSWORD, REDIS_PASSWORD (or uses auto-generated if skipped)

ENV="${1:-production}"
ENV_FILE=".env.${ENV}"
ENV_EXAMPLE="${ENV_FILE}.example"

if [ ! -f "$ENV_EXAMPLE" ]; then
    echo "❌ Template not found: ${ENV_EXAMPLE}"
    echo "   Run 'make upload-env-template' first to upload the template file."
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 Generating secrets for ${ENV} environment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Copy template if env doesn't exist
if [ -f "$ENV_FILE" ]; then
    echo "⚠️  ${ENV_FILE} already exists."
    read -rp "   Overwrite? [y/N] " confirm
    if [ "${confirm,,}" != "y" ]; then
        echo "   Skipped."
        exit 0
    fi
fi
cp "$ENV_EXAMPLE" "$ENV_FILE"

# Auto-generate secrets
APP_KEY=$(docker run --rm ghcr.io/thaolaptrinh/laravel-viltf:dev php artisan key:generate --show 2>/dev/null || \
          php -r "echo 'base64:' . base64_encode(random_bytes(32));")
REVERB_KEY=$(openssl rand -hex 16)
REVERB_SECRET=$(openssl rand -hex 32)
TRAEFIK_AUTH_HASH=$(echo -n "admin:$(openssl rand -base64 12)" | base64)

# Prompt for DB password
read -rsp "🔑 DB password (ENTER for auto-generate): " DB_PASS
echo ""
if [ -z "$DB_PASS" ]; then
    DB_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 24)
    echo "   Auto-generated: $DB_PASS (saved to ${ENV_FILE})"
fi

# Prompt for Redis password
read -rsp "🔑 Redis password (ENTER for auto-generate): " REDIS_PASS
echo ""
if [ -z "$REDIS_PASS" ]; then
    REDIS_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 24)
    echo "   Auto-generated: $REDIS_PASS (saved to ${ENV_FILE})"
fi

# Prompt for domain
read -rp "🌐 App domain (e.g., yourdomain.com): " APP_DOMAIN
if [ -z "$APP_DOMAIN" ]; then
    echo "❌ Domain is required"
    exit 1
fi

# Replace placeholders in env file
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

# Generate Traefik basic auth (bcrypt)
if command -v htpasswd &>/dev/null; then
    TRAEFIK_PASS=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')
    TRAEFIK_AUTH=$(htpasswd -nbB admin "$TRAEFIK_PASS" | sed 's/\$/$$/g')
    sed -i "s|TRAEFIK_AUTH=.*|TRAEFIK_AUTH=${TRAEFIK_AUTH}|" "$ENV_FILE"
    echo "   Traefik dashboard: admin / $TRAEFIK_PASS"
fi

echo ""
echo "════════════════════════════════"
echo "✅ ${ENV_FILE} ready"
echo "════════════════════════════════"
echo ""
echo "Secrets saved to ${ENV_FILE}"
echo ""
echo "Next: make upload-certs && make deploy-${ENV}"
