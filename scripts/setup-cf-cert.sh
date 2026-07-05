#!/usr/bin/env bash
set -euo pipefail

# ─── setup-cf-cert.sh ─────────────────────────────────────────────────────────
# Generate Cloudflare Origin Certificate via API.
# Saves cert.pem + private.key to docker/traefik/certs/
#
# Usage:
#   make setup-cf-cert APP_DOMAIN=yourdomain.com
#   make setup-cf-cert CF_API_TOKEN=xxx APP_DOMAIN=yourdomain.com  (non-interactive)
#
# Prerequisites:
#   - CF API Token with "Origin CA:Edit" permission
#   - python3 (for JSON parsing)

CERTS_DIR="docker/traefik/certs"

# Prompt for missing values (env var → interactive input)
CF_API_TOKEN="${CF_API_TOKEN:-}"
if [ -z "$CF_API_TOKEN" ]; then
    read -rsp "🔑 CF API Token (Origin CA:Edit scope, input hidden): " CF_API_TOKEN
    echo ""
    [ -z "$CF_API_TOKEN" ] && { echo "❌ Token required"; exit 1; }
fi

APP_DOMAIN="${APP_DOMAIN:-}"
if [ -z "$APP_DOMAIN" ]; then
    read -rp "🌐 Domain (e.g., yourdomain.com): " APP_DOMAIN
    echo ""
    [ -z "$APP_DOMAIN" ] && { echo "❌ Domain required"; exit 1; }
fi

echo "🔐 Generating CF Origin Cert for *.${APP_DOMAIN} + ${APP_DOMAIN} (15 years)..."

mkdir -p "$CERTS_DIR"

# Single API call — cert + key from same response (calling twice = 2 different certs)
response=$(curl -sf -X POST "https://api.cloudflare.com/client/v4/certificates" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"hostnames\": [\"*.${APP_DOMAIN}\", \"${APP_DOMAIN}\"],
        \"requested_validity\": 5475,
        \"request_type\": \"origin-rsa\",
        \"rsa_key_size\": 2048
    }")

# Parse JSON response — extract cert + private key from ONE call
echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if not data.get('success'):
    errors = data.get('errors', [{'message': 'Unknown error'}])
    print(f\"❌ CF API error: {errors[0].get('message', 'Unknown')}\")
    sys.exit(1)
result = data['result']
with open('${CERTS_DIR}/cert.pem', 'w') as f:
    f.write(result['certificate'])
with open('${CERTS_DIR}/private.key', 'w') as f:
    f.write(result['private_key'])
print('✅ Saved:')
print(f'   ${CERTS_DIR}/cert.pem')
print(f'   ${CERTS_DIR}/private.key')
"

chmod 600 "${CERTS_DIR}/private.key"
chmod 644 "${CERTS_DIR}/cert.pem"

echo ""
echo "📋 Next steps:"
echo "   make upload-certs SSH_USER=user SSH_HOST=your-vps-ip"
