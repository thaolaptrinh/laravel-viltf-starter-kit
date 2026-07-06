#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/thaolaptrinh/laravel-viltf}"

echo "→ Generating Wayfinder types (needs running dev app)..."
cp .env.example .env
# Generate before Docker build — assets stage is Node-only, no PHP.
docker compose -f compose.yaml -f compose.override.yaml run --rm -T app \
    php -d opcache.file_cache=/tmp -d opcache.validate_timestamps=1 \
    artisan wayfinder:generate --with-form 2>/dev/null || {
    echo "  WARNING: Wayfinder generation failed. Start 'make dev' first?"
}
rm -f .env

echo "→ Building production image..."
docker build --target=production -t "${IMAGE}:local" -f Dockerfile .

echo "→ Cleaning up Wayfinder artifacts..."
rm -f resources/js/wayfinder/*.ts resources/js/routes/*.ts resources/js/actions/*.ts 2>/dev/null || true

echo ""
echo "✅ Production image built: ${IMAGE}:local"
