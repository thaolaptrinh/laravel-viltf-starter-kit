#!/usr/bin/env bash
set -euo pipefail

# ─── setup-cf-dns.sh ──────────────────────────────────────────────────────────
# Configure Cloudflare DNS + SSL for the app domain via API.
#
#   1. Creates A records: yourdomain.com + traefik.yourdomain.com → VPS_IP
#   2. Sets SSL/TLS mode = Full (strict)
#
# Run ON VPS (so IP autodetects) or locally with explicit VPS_IP:
#   make setup-cf-dns CF_API_TOKEN=... APP_DOMAIN=... [VPS_IP=...]
#
# Token scope: Zone.Zone:Read, Zone.DNS:Edit, Zone.Settings:Edit
# (Origin CA:Edit separate — use setup-cf-cert.sh)
#
# Idempotent: re-running updates existing records in place.

CF_API_TOKEN="${CF_API_TOKEN:-}"
APP_DOMAIN="${APP_DOMAIN:-}"
VPS_IP="${VPS_IP:-}"

[ -z "$CF_API_TOKEN" ] && { echo "❌ CF_API_TOKEN required"; exit 1; }
[ -z "$APP_DOMAIN" ]   && { echo "❌ APP_DOMAIN required"; exit 1; }

# Autodetect VPS IP if not provided (when run on VPS)
if [ -z "$VPS_IP" ]; then
    VPS_IP=$(curl -sf https://ifconfig.me 2>/dev/null || curl -sf https://api.ipify.org 2>/dev/null)
    [ -z "$VPS_IP" ] && { echo "❌ VPS_IP required (autodetect failed)"; exit 1; }
    echo "🌐 Autodetected VPS IP: $VPS_IP"
fi

AUTH=(-H "Authorization: Bearer ${CF_API_TOKEN}" -H "Content-Type: application/json")

# ─── Find zone ID for APP_DOMAIN ─────────────────────────────────────────────
ZONE=$(curl -sf "${AUTH[@]}" "https://api.cloudflare.com/client/v4/zones?name=${APP_DOMAIN}")
ZONE_ID=$(echo "$ZONE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if not data.get('success') or not data.get('result'):
    print('')
else:
    print(data['result'][0]['id'])
")
[ -z "$ZONE_ID" ] && { echo "❌ Zone not found for ${APP_DOMAIN}. Is domain added to CF?"; exit 1; }
echo "✅ Zone: ${APP_DOMAIN} (${ZONE_ID})"

# ─── Upsert DNS records ──────────────────────────────────────────────────────
upsert_record() {
    local name="$1"
    local existing=$(curl -sf "${AUTH[@]}" \
        "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=A&name=${name}")
    local record_id=$(echo "$existing" | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('result', [])
print(results[0]['id'] if results else '')
")

    local body="{\"type\":\"A\",\"name\":\"${name}\",\"content\":\"${VPS_IP}\",\"proxied\":true,\"ttl\":1}"

    if [ -n "$record_id" ]; then
        curl -sf -X PUT "${AUTH[@]}" \
            "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${record_id}" \
            -d "$body" >/dev/null
        echo "✅ Updated A record: ${name} → ${VPS_IP} (proxied)"
    else
        curl -sf -X POST "${AUTH[@]}" \
            "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
            -d "$body" >/dev/null
        echo "✅ Created A record: ${name} → ${VPS_IP} (proxied)"
    fi
}

upsert_record "${APP_DOMAIN}"
upsert_record "traefik.${APP_DOMAIN}"

# ─── Set SSL mode = Full (strict) ────────────────────────────────────────────
# Show CF error on failure (don't swallow with >/dev/null)
RESP=$(curl -s -X PATCH "${AUTH[@]}" \
    "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/ssl" \
    -d '{"value":"strict"}')
if echo "$RESP" | python3 -c "import sys,json; sys.exit(0 if json.load(sys.stdin).get('success') else 1)" 2>/dev/null; then
    echo "✅ SSL/TLS mode: Full (strict)"
else
    echo "⚠️  SSL mode update failed. CF response: $RESP"
    echo "   Token may lack Zone.Settings:Edit scope. Continuing..."
fi

# ─── Always Use HTTPS = On ───────────────────────────────────────────────────
RESP=$(curl -s -X PATCH "${AUTH[@]}" \
    "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/always_use_https" \
    -d '{"value":"on"}')
if echo "$RESP" | python3 -c "import sys,json; sys.exit(0 if json.load(sys.stdin).get('success') else 1)" 2>/dev/null; then
    echo "✅ Always Use HTTPS: On"
else
    echo "⚠️  Always Use HTTPS update failed. CF response: $RESP"
    echo "   Token may lack Zone.Settings:Edit scope. Continuing..."
fi

echo ""
echo "════════════════════════════════"
echo "✅ DNS + SSL configured"
echo "════════════════════════════════"
echo ""
echo "Note: DNS propagation may take 1-5 min. Verify with:"
echo "  dig +short ${APP_DOMAIN}"
