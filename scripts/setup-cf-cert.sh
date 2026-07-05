#!/usr/bin/env bash
set -euo pipefail

# ─── setup-cf-cert.sh ─────────────────────────────────────────────────────────
# Generate Cloudflare Origin Certificate via API.
# Saves cert.pem + private.key to docker/traefik/certs/
#
# Usage:
#   ./scripts/setup-cf-cert.sh <CF_API_TOKEN> <APP_DOMAIN>
#   make setup-cf-cert CF_API_TOKEN=xxx APP_DOMAIN=yourdomain.com
#
# Prerequisites:
#   - CF API Token with "Origin CA:Edit" permission
#     (Cloudflare Dashboard → My Profile → API Tokens → Create Token)
#   - python3 (for JSON parsing)

CF_API_TOKEN="${1:?❌ Usage: setup-cf-cert.sh <CF_API_TOKEN> <APP_DOMAIN>}"
APP_DOMAIN="${2:?❌ Usage: setup-cf-cert.sh <CF_API_TOKEN> <APP_DOMAIN>}"
CERTS_DIR="docker/traefik/certs"

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
