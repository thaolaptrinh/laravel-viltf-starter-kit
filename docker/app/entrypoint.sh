#!/usr/bin/env sh
set -e

if [ "$(id -u)" = "0" ]; then
    chown -R ${USER}:${GROUP} ${ROOT}/storage ${ROOT}/bootstrap/cache 2>/dev/null || true
fi

php artisan storage:link 2>/dev/null || true
# Clear stale cache from build-time (no APP_KEY), then re-cache with runtime env.
# skip route:cache — incompatible with Octane's CompiledRouteCollection
php artisan optimize:clear 2>/dev/null || true
php artisan config:cache 2>/dev/null
php artisan event:cache 2>/dev/null

exec "$@"
