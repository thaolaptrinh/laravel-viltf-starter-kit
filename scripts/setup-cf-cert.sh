#!/usr/bin/env bash
set -euo pipefail

# ─── setup-cf-cert.sh ─────────────────────────────────────────────────────────
# Generate Cloudflare Origin Certificate via API with openssl CSR.
# Saves cert.pem + private.key to docker/traefik/certs/ (in CWD).
#
# Run ON VPS so private key never touches laptop.
#
# Token needs: Zone.Zone:Read + Zone.SSL and Certificates:Edit

CERTS_DIR="docker/traefik/certs"

CF_API_TOKEN="${CF_API_TOKEN:-}"
[ -z "$CF_API_TOKEN" ] && read -rsp "CF API Token (input hidden): " CF_API_TOKEN && echo
[ -z "$CF_API_TOKEN" ] && { echo "❌ Token required"; exit 1; }

APP_DOMAIN="${APP_DOMAIN:-}"
[ -z "$APP_DOMAIN" ] && read -rp "Domain: " APP_DOMAIN
[ -z "$APP_DOMAIN" ] && { echo "❌ Domain required"; exit 1; }

echo "🔐 Generating CF Origin Cert for *.${APP_DOMAIN} + ${APP_DOMAIN} (15 years)..."

mkdir -p "$CERTS_DIR"

# Generate RSA private key + CSR (CF requires CSR for origin-rsa)
openssl req -new -newkey rsa:2048 -nodes -keyout "${CERTS_DIR}/private.key" \
    -subj "/CN=${APP_DOMAIN}/O=Laravel VILTF" \
    -out "${CERTS_DIR}/request.csr" 2>/dev/null

CSR=$(cat "${CERTS_DIR}/request.csr" | sed 's/$/\\n/' | tr -d '\n')

response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/certificates" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"hostnames\": [\"*.${APP_DOMAIN}\", \"${APP_DOMAIN}\"],
        \"requested_validity\": 5475,
        \"request_type\": \"origin-rsa\",
        \"csr\": \"${CSR}\"
    }")

rm -f "${CERTS_DIR}/request.csr"

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
print('✅ cert.pem saved')
"

chmod 600 "${CERTS_DIR}/private.key"
chmod 644 "${CERTS_DIR}/cert.pem"
echo "   ${CERTS_DIR}/private.key"
echo "   ${CERTS_DIR}/cert.pem"
