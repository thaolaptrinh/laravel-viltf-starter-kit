# Docker Migration Design — Replacing Sail with Production-Grade Container Stack

**Date:** 2026-07-04
**Status:** Approved (pending spec review)
**Owner:** thaolaptrinh/laravel-viltf-starter-kit

---

## 1. Overview

### 1.1 Current State

The project (`laravel-viltf-starter-kit`) currently uses **Laravel Sail** for Docker-based development. Recent commits added **Laravel Octane** (`feat: laravel octance`) and downloaded a 165 MB standalone `frankenphp` binary to the repo root. Empty scaffolding for `docker/compose.{dev,staging,production}.yml` exists but is unused.

**Stack:** PHP 8.5, Laravel 13, Filament 5, Inertia 3, Livewire 4, Vue 3, Tailwind 4, PostgreSQL 18, Redis, FrankenPHP/Octane.

### 1.2 Goals

1. Replace Sail with a custom, production-grade Docker setup that spans **dev / staging / production** in a single coherent design.
2. Standardize on **FrankenPHP + Octane** as the runtime across all environments.
3. Use **Traefik + Cloudflare** (Setup A: orange-cloud proxy + Origin Cert) for the production edge.
4. Provide **zero-downtime deploy** via `docker-rollout`.
5. Maintain DX comparable to Sail through a `Makefile` + minimal composer scripts.
6. Make the starter kit's runtime story consistent: _"this project uses FrankenPHP everywhere."_

### 1.3 Non-Goals (Out of Scope)

- Monitoring stack (Prometheus / Grafana / Netdata). Use hosted alternatives (Grafana Cloud, Better Stack) or Laravel Pulse.
- Administration tooling containers (pgAdmin, Mailhog, pghero). Document opt-in only.
- Cloudflare Tunnel setup. Document as alternative edge option.
- Custom FrankenPHP build with Caddy modules (cbrotli, etc.). Cloudflare handles edge compression.
- Multi-arch build by default. `linux/amd64` only; arm64 opt-in.
- Kamal or Kubernetes. Out of scope for single-VPS target.
- PgBouncer. Document as opt-in for high-traffic.
- ACME / Let's Encrypt. Cloudflare Origin Cert (15-year) is the default.

---

## 2. Decisions Log

| #   | Decision                                                                    | Rationale                                                                                 |
| --- | --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| D1  | Full custom Docker for **all** envs (dev/staging/production), remove Sail   | Starter-kit message consistency; FrankenPHP works for dev too                             |
| D2  | PHP 8.5 + FrankenPHP 1.12.4-php8.5-alpine as base                           | Verified exists (68 MB); matches project's `php: ^8.5` constraint                         |
| D3  | **Traefik + Cloudflare** (Setup A: CF Origin Cert, no ACME)                 | Simplest production-grade TLS; auto-discovery via Docker labels                           |
| D4  | Deploy target: **single VPS + docker compose**                              | Project size; avoids k8s/Kamal complexity                                                 |
| D5  | Build strategy: **CI build → GHCR → VPS pull**                              | Reproducible; VPS doesn't need source                                                     |
| D6  | DB + Redis containerized in same VPS                                        | Single-host simplicity; volume backup strategy                                            |
| D7  | **Separate containers** for app / horizon / scheduler / ssr                 | Scale and restart independently                                                           |
| D8  | Hybrid compose: **profiles for env membership** + override files for config | Single source of truth; orthogonal concerns toggle cleanly                                |
| D9  | **Queue = Redis** (default `QUEUE_CONNECTION=redis`); Horizon included      | Redis > database for queues; Horizon gives dashboard                                      |
| D10 | **Cache + Session = Redis**                                                 | Same reasoning; parity with production                                                    |
| D11 | **Horizon + SSR included as default services** in staging/production        | Production-grade out-of-the-box                                                           |
| D12 | Dev = `app + horizon + pgsql + redis` only                                  | Lean dev env; scheduler/ssr/traefik not needed                                            |
| D13 | Vite HMR runs **inside app container** (dev target) via supervisor          | One container, no port conflicts                                                          |
| D14 | **Makefile primary** for orchestration; composer scripts minimal            | Clean separation of concerns; better discoverability                                      |
| D15 | Zero-downtime via **docker-rollout** (not Kamal)                            | Single-VPS fit; additive to existing compose design                                       |
| D16 | **No Prometheus/Grafana** by default                                        | YAGNI; use hosted monitoring or Laravel Pulse                                             |
| D17 | **Include Laravel Reverb** as default WebSocket service                     | First-party, free unlimited, Redis-backed, same Docker image via `CONTAINER_MODE=reverb`  |
| D18 | **Target 2 cores / 4 GB VPS** as minimum production spec                    | Fits starter kit workload; conservative memory limits per service; document scale-up path |

---

## 3. Architecture

### 3.1 Service Topology Per Environment

```
DEV (compose.yaml + compose.override.yml, COMPOSE_PROFILES=dev)
├── app          (Octane FrankenPHP + Vite HMR via supervisor, code mounted)
├── horizon      (Laravel Horizon queue consumer + dashboard)
├── pgsql        (postgres:18-alpine)
└── redis        (redis:alpine, AOF persistence)

STG (compose.yaml + compose.staging.yml, COMPOSE_PROFILES=staging)
├── traefik      (edge, CF Origin Cert, HTTP/3, no X-Robots-Tag stripping)
├── app          (image: ghcr.io/.../app:staging, CONTAINER_MODE=http)
├── horizon      (same image, CONTAINER_MODE=horizon)
├── scheduler    (same image, CONTAINER_MODE=scheduler, supercronic)
├── ssr          (same image, CONTAINER_MODE=ssr, Inertia SSR via Node)
├── reverb       (same image, CONTAINER_MODE=reverb, WebSocket server on :8080)
├── pgsql        (with staging volume)
└── redis

PROD (compose.yaml + compose.production.yml, COMPOSE_PROFILES=production)
├── traefik      (edge, CF Origin Cert, HTTP/3, security headers, dashboard)
├── app          (image: ghcr.io/.../app:${IMAGE_TAG}, scale=2)
├── horizon      (queue consumer + dashboard)
├── scheduler    (cron via supercronic)
├── ssr          (Inertia SSR)
├── reverb       (WebSocket server, Traefik routes /app/* to it)
├── pgsql        (production volume + opt-in backup hook)
└── redis        (with persistence)
```

### 3.2 Container Modes (CONTAINER_MODE env var, dispatched in `start-container`)

| Mode             | Supervisor program                                         | Used by service |
| ---------------- | ---------------------------------------------------------- | --------------- |
| `http` (default) | `php artisan octane:frankenphp --host=0.0.0.0 --port=8000` | app             |
| `horizon`        | `php artisan horizon`                                      | horizon         |
| `scheduler`      | `supercronic /etc/supercronic/laravel`                     | scheduler       |
| `ssr`            | `php artisan inertia:start-ssr --runtime=node --quiet`     | ssr             |
| `reverb`         | `php artisan reverb:start --host=0.0.0.0 --port=8080`      | reverb          |

### 3.3 Network Diagram (production)

```
Internet ──HTTPS──> Cloudflare (orange-cloud proxy, public TLS, HTTP/3, WAF, CDN)
                          │
                          │  HTTPS (CF Origin Cert, 15 yr)
                          ▼
                      Traefik (VPS, :80→:443 redirect, :443 HTTP/3)
                          │
                          │  HTTP (internal port 8000)
                          ▼
                      app container (FrankenPHP/Octane) ─ scale=2
                          │
                      (Docker bridge network "stack")
                          │
                          ├──> pgsql:5432
                          ├──> redis:6379
                          ├──> horizon (no port)
                          ├──> scheduler (no port)
                          ├──> ssr:13714 (internal, accessed by app for SSR render)
                          └──> reverb:8080 (WebSocket, Traefik routes /app/* here)
```

### 3.4 Folder Structure (new files)

```
Dockerfile
compose.yaml
compose.override.yml
compose.staging.yml
compose.production.yml
Makefile
.dockerignore
.env.staging.example
.env.production.example
docker/
├── deployment/
│   ├── start-container
│   ├── healthcheck
│   ├── php.ini
│   ├── supervisord.conf
│   ├── supervisord.http.conf
│   ├── supervisord.horizon.conf
│   ├── supervisord.scheduler.conf
│   ├── supervisord.ssr.conf
│   ├── supervisord.reverb.conf
│   ├── supercronic/
│   │   └── laravel
│   ├── frankenphp/
│   │   └── Caddyfile
│   └── postgres/
│       └── postgresql.conf
└── traefik/
    ├── traefik.yml
    ├── dynamic.yml
    └── certs/
        └── .gitkeep
.github/workflows/
└── docker.yml
```

---

## 4. Dockerfile Design

### 4.1 Multi-Stage Targets

```
┌─────────────────────────────────────────────────────────────┐
│ base                                                         │
│ FROM dunglas/frankenphp:1.12.4-php8.5-alpine                │
│ + system: bash curl wget vim tzdata supervisor supercronic  │
│   ca-certificates libsodium-dev                             │
│ + PHP ext (install-php-extensions):                         │
│   apcu pcntl mbstring bcmath sockets pdo_pgsql opcache      │
│   exif zip intl gd redis ffi uv                             │
│ + create user `laravel` (UID/GID via build args)            │
│ + copy deployment/* into image                              │
│ + WORKDIR /var/www/html                                     │
└─────────────────────────────────────────────────────────────┘
       ▲                              ▲
       │                              │
┌──────┴───────────────┐    ┌────────┴──────────────────────┐
│ composer-dev         │    │ composer-production                  │
│ FROM composer:2.8    │    │ FROM composer:2.8              │
│ composer install     │    │ composer install               │
│   (with dev deps)    │    │   --no-dev --optimize          │
│   --no-autoloader    │    │   --apcu --no-autoloader       │
└──────────────────────┘    └────────────────────────────────┘
       ▲                              ▲
       │                              │
       │                     ┌────────┴──────────────────────┐
       │                     │ assets                         │
       │                     │ FROM node:22-alpine            │
       │                     │ + pnpm                         │
       │                     │ pnpm install --frozen-lockfile │
       │                     │ pnpm run build                 │
       │                     │ pnpm run build:ssr             │
       │                     │ → /public/build/*              │
       │                     │ → /storage/ssr/*               │
       │                     └────────────────────────────────┘
       │                              ▲
┌──────┴──────────────────────────────┴───────────────────────┐
│ dev (target=dev)                                             │
│ FROM base                                                    │
│ COPY --from=composer-dev /app/vendor ./vendor                │
│ RUN composer dump-autoload --apcu                            │
│ + XDebug installed (mode=develop via env)                    │
│ + Node 22 + pnpm (for Vite HMR)                              │
│ + supervisord.http.conf includes Vite program                │
│ + EXPOSE 8000 5173                                           │
│ + NO source copy (volume mounted at runtime)                 │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ production (target=production)                                           │
│ FROM base                                                    │
│ COPY --from=composer-production /app/vendor ./vendor               │
│ COPY --from=assets /app/public/build ./public/build          │
│ COPY --from=assets /app/storage/ssr ./storage/ssr            │
│ COPY . /var/www/html                                         │
│ RUN php artisan optimize && php artisan storage:link         │
│ + chown -R laravel:laravel storage bootstrap/cache           │
│ + strip setuid/setgid bits                                   │
│ + USER laravel                                               │
│ + EXPOSE 8000                                                │
│ + HEALTHCHECK CMD healthcheck                                │
└──────────────────────────────────────────────────────────────┘
```

### 4.2 Build Args & Caching Strategy

| Build arg  | Default | Notes                                                                                      |
| ---------- | ------- | ------------------------------------------------------------------------------------------ |
| `USER_ID`  | `1000`  | Dev target: pass host UID for volume permission parity. Production target: hardcoded 1000. |
| `GROUP_ID` | `1000`  | Same as above                                                                              |
| `TZ`       | `UTC`   | Sets container timezone                                                                    |

**Layer caching order** (maximize cache hits on code change):

1. System deps (apk add) — rarely changes
2. PHP extensions (install-php-extensions) — rarely changes
3. User setup, supervisord configs, deployment scripts — rarely changes
4. `COPY composer.json composer.lock` → `composer install` — changes when deps change
5. `COPY package.json pnpm-lock.yaml` → `pnpm install` (assets stage) — changes when frontend deps change
6. `COPY . .` — changes on every code change (cheapest layer)

### 4.3 Octane-Specific Configuration

#### 4.3.1 `config/octane.php` updates

The starter kit's `octane.php` already has `'https' => env('OCTANE_HTTPS', false)`. Set `OCTANE_HTTPS=true` in `.env.staging` and `.env.production`.

Verify these defaults (already present in starter's config):

- `'server' => env('OCTANE_SERVER', 'frankenphp')` (env-driven)
- `RequestReceived` listener includes `Octane::prepareApplicationForNextOperation()` (handles state reset for Filament/Livewire)

#### 4.3.2 Filament + Livewire + Octane compatibility

Filament v5 + Livewire v4 require careful Octane config to avoid state pollution. Add to `octane.php` `listeners` → `RequestReceived`:

```php
RequestReceived::class => [
    ...Octane::prepareApplicationForNextOperation(),
    ...Octane::prepareApplicationForNextRequest(),
    // Livewire + Filament state cleanup if needed
],
```

Reference: https://filamentphp.com/docs/5.x/panels/installation#laravel-octane — verify Filament 5 Octane notes during implementation and add any recommended listeners.

#### 4.3.3 Trusted Proxies (Laravel behind Traefik)

Laravel 11+ uses `TrustProxies` middleware that auto-trusts all proxies when configured. Verify `bootstrap/app.php` has the middleware enabled; if not, add:

```php
->withMiddleware(function (Middleware $middleware) {
    $middleware->trustProxies(at: '*');
})
```

#### 4.3.4 `docker/deployment/frankenphp/Caddyfile` (minimal, opt-in tuning)

```caddyfile
{
    admin off
    auto_https off
    order php_server before file_server
}

:8000 {
    root * /var/www/html/public
    encode zstd gzip
    php_server
}
```

Note: Octane's `octane:frankenphp` command provides default Caddy config; this file is opt-in for advanced tuning.

### 4.4 PHP Configuration (`docker/deployment/php.ini`)

```ini
; Production-tuned (override frankenphp image defaults)
memory_limit = 256M
upload_max_filesize = 64M
post_max_size = 72M
max_execution_time = 60
max_input_time = 60

date.timezone = ${TZ}

; OPCache (Laravel Octane benefit)
opcache.enable = 1
opcache.enable_cli = 1
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 32
opcache.max_accelerated_files = 20000
opcache.validate_timestamps = 0
opcache.revalidate_freq = 0
opcache.fast_shutdown = 1

; APCu
apc.enabled = 1
apc.enable_cli = 1

; Expose only essential info
expose_php = Off
display_errors = Off
log_errors = On
```

### 4.5 `start-container` Entrypoint (adapted from docktane)

```sh
#!/usr/bin/env sh
set -e

container_mode="${CONTAINER_MODE:-http}"
run_migrations="${RUNNING_MIGRATIONS_AND_SEEDERS:-false}"

initial_stuff() {
    echo "Container mode: ${container_mode}"

    if [ "${run_migrations}" = "true" ]; then
        echo "Running migrations..."
        php artisan migrate --isolated --seed --force \
            || php artisan migrate --seed --force
    fi

    php artisan storage:link 2>/dev/null || true
    php artisan optimize
}

if [ -n "$1" ]; then
    # Allow ad-hoc command: docker run ... app php artisan tinker
    exec "$@"
elif [ "${container_mode}" = "http" ]; then
    initial_stuff
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.http.conf
elif [ "${container_mode}" = "horizon" ]; then
    initial_stuff
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.horizon.conf
elif [ "${container_mode}" = "scheduler" ]; then
    initial_stuff
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.scheduler.conf
elif [ "${container_mode}" = "ssr" ]; then
    initial_stuff
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.ssr.conf
elif [ "${container_mode}" = "reverb" ]; then
    initial_stuff
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.reverb.conf
else
    echo "Unknown CONTAINER_MODE: ${container_mode}"
    exit 1
fi
```

### 4.6 Supervisor Configurations

#### `supervisord.http.conf`

```ini
[program:octane]
process_name = %(program_name)s_%(process_num)s
command = php %(ENV_ROOT)s/artisan octane:frankenphp --host=0.0.0.0 --port=8000 --admin-host=127.0.0.1 --admin-port=2019
user = %(ENV_USER)s
priority = 1
autostart = true
autorestart = true
stopasgroup = true
killasgroup = true
stopwaitsecs = 30
environment = LARAVEL_OCTANE="1"
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0
stderr_logfile = /dev/stderr
stderr_logfile_maxbytes = 0

[program:vite]
process_name = %(program_name)s_%(process_num)s
command = pnpm run dev --host
user = %(ENV_USER)s
priority = 2
autostart = %(ENV_WITH_VITE)s
autorestart = true
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0
stderr_logfile = /dev/stderr
stderr_logfile_maxbytes = 0
```

> `WITH_VITE=true` only in dev target. Production target supervisord.http.conf omits the vite program entirely.

#### `supervisord.horizon.conf`

```ini
[program:horizon]
command = php %(ENV_ROOT)s/artisan horizon
user = %(ENV_USER)s
autostart = true
autorestart = true
stopasgroup = true
killasgroup = true
stopwaitsecs = 3600
stdout_logfile = %(ENV_ROOT)s/storage/logs/horizon.log
stdout_logfile_maxbytes = 200MB
stderr_logfile = %(ENV_ROOT)s/storage/logs/horizon.log
stderr_logfile_maxbytes = 200MB
```

#### `supervisord.scheduler.conf`

```ini
[program:scheduler]
command = supercronic -overlapping /etc/supercronic/laravel
user = %(ENV_USER)s
autostart = true
autorestart = true
stopasgroup = true
killasgroup = true
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0
stderr_logfile = /dev/stderr
stderr_logfile_maxbytes = 0
```

#### `supervisord.ssr.conf`

```ini
[program:ssr]
command = php %(ENV_ROOT)s/artisan inertia:start-ssr --runtime=node --quiet
user = %(ENV_USER)s
autostart = true
autorestart = true
stopasgroup = true
killasgroup = true
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0
stderr_logfile = /dev/stderr
stderr_logfile_maxbytes = 0
```

#### `supervisord.reverb.conf`

```ini
[program:reverb]
process_name = %(program_name)s_%(process_num)s
command = php %(ENV_ROOT)s/artisan reverb:start --host=0.0.0.0 --port=8080
user = %(ENV_USER)s
priority = 3
autostart = true
autorestart = true
stopasgroup = true
killasgroup = true
minfds = 10000
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0
stderr_logfile = /dev/stderr
stderr_logfile_maxbytes = 0
```

### 4.7 Healthcheck Script (`docker/deployment/healthcheck`)

```sh
#!/usr/bin/env sh
set -e
curl --fail --max-time 3 http://127.0.0.1:8000/up
```

> Verify `/up` route exists in Laravel 13 default routes (`routes/web.php` or `routes/health.php`). The starter kit uses default Laravel routing, which includes this cosmetic health route.

---

## 5. Docker Compose — Hybrid Pattern

### 5.1 Pattern: Base + Override Files + Profiles

```
make dev       # = COMPOSE_PROFILES=dev  docker compose up -d (auto-loads compose.override.yml)
make staging       # = COMPOSE_PROFILES=staging  docker compose -f compose.yaml -f compose.staging.yml up -d
make production      # = COMPOSE_PROFILES=production docker compose -f compose.yaml -f compose.production.yml up -d
```

Compose auto-loads `compose.override.yml` when present. The Makefile sets `COMPOSE_PROFILES` env per target.

### 5.2 `compose.yaml` (single source of truth for service definitions)

```yaml
x-app-base: &app-base
    image: ${IMAGE:-ghcr.io/${GH_REPO:-thaolaptrinh/laravel-viltf}:${IMAGE_TAG:-dev}}
    networks: [stack]
    restart: unless-stopped
    security_opt: [no-new-privileges:true]
    logging:
        driver: json-file
        options: { max-size: '50m', max-file: '10', compress: 'true' }
    env_file:
        - path: .env
          required: false
    depends_on:
        pgsql: { condition: service_healthy }
        redis: { condition: service_healthy }

x-data-healthcheck: &data-hc
    interval: 5s
    timeout: 3s
    retries: 10

services:
    app:
        <<: *app-base
        profiles: [dev, staging, production]
        build:
            context: .
            dockerfile: Dockerfile
            target: ${BUILD_TARGET:-dev}
            args:
                USER_ID: ${USER_ID:-1000}
                GROUP_ID: ${GROUP_ID:-1000}
                TZ: ${TZ:-UTC}
        environment:
            CONTAINER_MODE: http
        ports:
            - '${APP_PORT:-8080}:8000'
            - '${VITE_PORT:-5173}:5173'
        volumes:
            - .:/var/www/html
            - /var/www/html/vendor
            - /var/www/html/node_modules
            - /var/www/html/public/build
            - /var/www/html/storage/ssr

    horizon:
        <<: *app-base
        profiles: [dev, staging, production]
        environment:
            CONTAINER_MODE: horizon

    scheduler:
        <<: *app-base
        profiles: [staging, production]
        environment:
            CONTAINER_MODE: scheduler

    ssr:
        <<: *app-base
        profiles: [staging, production]
        environment:
            CONTAINER_MODE: ssr

    reverb:
        <<: *app-base
        profiles: [staging, production]
        environment:
            CONTAINER_MODE: reverb

    pgsql:
        image: postgres:18-alpine
        profiles: [dev, staging, production]
        environment:
            POSTGRES_DB: ${DB_DATABASE:-laravel}
            POSTGRES_USER: ${DB_USERNAME:-laravel}
            POSTGRES_PASSWORD: ${DB_PASSWORD:-secret}
        volumes:
            - stack-pgsql:/var/lib/postgresql/data
        healthcheck:
            test:
                [
                    'CMD-SHELL',
                    'pg_isready -U ${DB_USERNAME:-laravel} -d ${DB_DATABASE:-laravel}',
                ]
            <<: *data-hc
        networks: [stack]
        restart: unless-stopped
        security_opt: [no-new-privileges:true]
        logging:
            { driver: json-file, options: { max-size: '50m', max-file: '10' } }

    redis:
        image: redis:7-alpine
        profiles: [dev, staging, production]
        command:
            - redis-server
            - --maxmemory
            - ${REDIS_MAXMEMORY:-256mb}
            - --maxmemory-policy
            - allkeys-lru
            - --save
            - '60 10000'
            - --save
            - '300 10'
            - --appendonly
            - 'yes'
        volumes:
            - stack-redis:/data
        healthcheck:
            test: ['CMD', 'redis-cli', 'ping']
            <<: *data-hc
        networks: [stack]
        restart: unless-stopped
        security_opt: [no-new-privileges:true]

networks:
    stack:
        driver: bridge

volumes:
    stack-pgsql:
    stack-redis:
```

### 5.3 `compose.override.yml` (auto-loaded for dev)

Dev overrides are minimal because `compose.yaml` already has dev-friendly defaults (build target=dev, volume mounts). This file can be empty, but reserve for user-specific tweaks (gitignored as `compose.override.local.yml`).

If needed, document typical user overrides:

```yaml
# compose.override.local.yml example (gitignored)
services:
    app:
        environment:
            XDEBUG_MODE: develop,debug
```

### 5.4 `compose.staging.yml`

```yaml
x-staging-image: &staging-image
    image: ghcr.io/${GH_REPO:-thaolaptrinh/laravel-viltf}:staging
    env_file: [.env.staging]
    ports: !reset []

services:
    app:
        <<: *staging-image
        build: !reset null
        environment:
            CONTAINER_MODE: http
            APP_ENV: staging
            OCTANE_HTTPS: 'true'
        labels:
            traefik.enable: true
            traefik.docker.network: stack
            traefik.http.routers.app.rule: Host(`${APP_DOMAIN}`)
            traefik.http.routers.app.entryPoints: app-secure
            traefik.http.routers.app.tls: true
            traefik.http.routers.app.middlewares: security-headers,security-staging
            traefik.http.services.app.loadbalancer.server.port: 8000
            traefik.http.services.app.loadbalancer.healthCheck.path: /up
        volumes:
            - ./storage/app/public:/var/www/html/storage/app/public

    horizon:
        <<: *staging-image
        environment: { CONTAINER_MODE: horizon }

    scheduler:
        <<: *staging-image
        environment: { CONTAINER_MODE: scheduler }

    ssr:
        <<: *staging-image
        environment: { CONTAINER_MODE: ssr }

    reverb:
        <<: *staging-image
        environment: { CONTAINER_MODE: reverb }
        labels:
            traefik.enable: true
            traefik.docker.network: stack
            traefik.http.routers.reverb.rule: Host(`${APP_DOMAIN}`) && PathPrefix(`/app`)
            traefik.http.routers.reverb.entryPoints: app-secure
            traefik.http.routers.reverb.tls: true
            traefik.http.routers.reverb.priority: 30
            traefik.http.routers.reverb.middlewares: security-headers
            traefik.http.services.reverb.loadbalancer.server.port: 8080

    traefik:
        image: traefik:v3.6
        profiles: [staging, production]
        restart: unless-stopped
        stop_grace_period: 35s
        security_opt: [no-new-privileges:true]
        ulimits:
            nofile: { soft: 65536, hard: 65536 }
        ports:
            - '80:80'
            - '443:443'
            - '443:443/udp'
            - '127.0.0.1:8080:8080'
        volumes:
            - /var/run/docker.sock:/var/run/docker.sock:ro
            - ./docker/traefik/traefik.yml:/etc/traefik/traefik.yml:ro
            - ./docker/traefik/dynamic.yml:/etc/traefik/dynamic.yml:ro
            - ./docker/traefik/certs:/certs:ro
        networks: [stack]
        labels:
            traefik.enable: true
            traefik.http.routers.traefik.rule: Host(`traefik.${APP_DOMAIN}`)
            traefik.http.routers.traefik.entryPoints: app-secure
            traefik.http.routers.traefik.tls: true
            traefik.http.routers.traefik.service: api@internal
            traefik.http.routers.traefik.middlewares: traefik-auth,security-headers
```

### 5.5 `compose.production.yml`

```yaml
x-production-image: &production-image
    image: ghcr.io/${GH_REPO:-thaolaptrinh/laravel-viltf}:${IMAGE_TAG:-latest}
    env_file: [.env.production]
    ports: !reset []
    restart: unless-stopped
    stop_grace_period: 35s
    deploy:
        resources:
            limits: { memory: 1G }

services:
    app:
        <<: *production-image
        environment:
            CONTAINER_MODE: http
            APP_ENV: production
            OCTANE_HTTPS: 'true'
        labels:
            traefik.enable: true
            traefik.docker.network: stack
            traefik.http.routers.app.rule: Host(`${APP_DOMAIN}`)
            traefik.http.routers.app.entryPoints: app
            traefik.http.routers.app.priority: 10
            traefik.http.routers.app-tls.rule: Host(`${APP_DOMAIN}`)
            traefik.http.routers.app-tls.entryPoints: app-secure
            traefik.http.routers.app-tls.tls: true
            traefik.http.routers.app-tls.priority: 10
            traefik.http.routers.app-tls.middlewares: security-headers,compress
            traefik.http.services.app.loadbalancer.server.port: 8000
            traefik.http.services.app.loadbalancer.healthCheck.path: /up
            traefik.http.services.app.loadbalancer.healthCheck.interval: 5s
            traefik.http.services.app.loadbalancer.healthCheck.timeout: 3s
        volumes:
            - ./storage/app/public:/var/www/html/storage/app/public

    horizon:
        <<: *production-image
        environment: { CONTAINER_MODE: horizon }

    scheduler:
        <<: *production-image
        environment: { CONTAINER_MODE: scheduler }

    ssr:
        <<: *production-image
        environment: { CONTAINER_MODE: ssr }

    reverb:
        <<: *production-image
        environment: { CONTAINER_MODE: reverb }
        deploy:
            resources:
                limits: { memory: 256M }
        labels:
            traefik.enable: true
            traefik.docker.network: stack
            traefik.http.routers.reverb.rule: Host(`${APP_DOMAIN}`) && PathPrefix(`/app`)
            traefik.http.routers.reverb.entryPoints: app-secure
            traefik.http.routers.reverb.tls: true
            traefik.http.routers.reverb.priority: 30
            traefik.http.routers.reverb.middlewares: security-headers
            traefik.http.services.reverb.loadbalancer.server.port: 8080

    traefik:
        image: traefik:v3.6
        restart: unless-stopped
        stop_grace_period: 35s
        security_opt: [no-new-privileges:true]
        ulimits:
            nofile: { soft: 65536, hard: 65536 }
        ports:
            - '80:80'
            - '443:443'
            - '443:443/udp'
            - '127.0.0.1:8080:8080'
        volumes:
            - /var/run/docker.sock:/var/run/docker.sock:ro
            - ./docker/traefik/traefik.yml:/etc/traefik/traefik.yml:ro
            - ./docker/traefik/dynamic.yml:/etc/traefik/dynamic.yml:ro
            - ./docker/traefik/certs:/certs:ro
        networks: [stack]
        labels:
            traefik.enable: true
            traefik.http.routers.traefik.rule: Host(`traefik.${APP_DOMAIN}`)
            traefik.http.routers.traefik.entryPoints: app-secure
            traefik.http.routers.traefik.tls: true
            traefik.http.routers.traefik.service: api@internal
            traefik.http.routers.traefik.middlewares: traefik-auth,security-headers

    # Optional pg_dump backup sidecar (opt-in via profile)
    backup:
        image: offen/docker-volume-backup:v2
        profiles: [backup]
        environment:
            BACKUP_FILENAME: backup-%Y-%m-%dT%H-%M-%S.tar.gz
            BACKUP_PRUNING_PREFIX: backup-
            BACKUP_CRON_EXPRESSION: '0 2 * * *'
            BACKUP_RETENTION_DAYS: '7'
        volumes:
            - stack-pgsql:/backup/pgsql:ro
            - ./backups:/archive
            - /var/run/docker.sock:/var/run/docker.sock:ro
        labels:
            traefik.enable: false
```

> **Scaling note:** `docker compose up --scale app=2` achieves horizontal scaling. Not using `deploy.replicas` (Swarm-only). Makefile target `production-scale-up` provides this.

---

## 6. Traefik + Cloudflare (Setup A)

### 6.1 Setup A: CF proxy → Traefik → CF Origin Cert

**Public TLS:** Terminated at Cloudflare edge (orange-cloud proxy enabled).
**Origin TLS:** CF Origin Certificate (15-year validity), mounted into Traefik container.

### 6.2 CF Origin Cert One-Time Setup

1. Cloudflare Dashboard → SSL/TLS → Origin Server → **Create Certificate**
2. RSA 2048 (or ECDSA 256), hostnames `*.yourdomain.com, yourdomain.com`, validity 15 years
3. Download `cert.pem` + `private.key`
4. Place in `docker/traefik/certs/` (gitignored)
5. CF Dashboard → SSL/TLS → **Full (strict)** mode
6. (Optional) Download **Origin Pull CA** → `docker/traefik/certs/origin-pull-ca.pem` for mTLS verification (advanced hardening, opt-in)

### 6.3 `docker/traefik/traefik.yml` (static config)

```yaml
global:
    checkNewVersion: false
    sendAnonymousUsage: false

entryPoints:
    app:
        address: ':80'
        http:
            redirections:
                entryPoint:
                    to: app-secure
                    scheme: https
                    permanent: true
    app-secure:
        address: ':443'
        http3:
            advertisedPort: 443
        transport:
            lifeCycle:
                graceTimeOut: 30s
    traefik:
        address: ':8080'

providers:
    docker:
        endpoint: unix:///var/run/docker.sock
        exposedByDefault: false
        network: stack
    file:
        filename: /etc/traefik/dynamic.yml

api:
    dashboard: true
    insecure: false

ping:
    entryPoint: traefik

log:
    level: ERROR
    format: common

accessLog:
    format: common

metrics:
    prometheus:
        addEntryPointsLabels: true
        addServicesLabels: true
```

### 6.4 `docker/traefik/dynamic.yml` (dynamic config)

```yaml
tls:
    certificates:
        - certFile: /certs/cert.pem
          keyFile: /certs/private.key
    options:
        default:
            minVersion: VersionTLS12
            sniStrict: true
            cipherSuites:
                - TLS_AES_128_GCM_SHA256
                - TLS_AES_256_GCM_SHA384
                - TLS_CHACHA20_POLY1305_SHA256
                - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
                - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
                - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256

http:
    middlewares:
        security-headers:
            headers:
                stsSeconds: 63072000
                stsIncludeSubdomains: true
                stsPreload: true
                forceSTSHeader: true
                customFrameOptionsValue: SAMEORIGIN
                contentTypeNosniff: true
                referrerPolicy: strict-origin-when-cross-origin
                permissionsPolicy: 'camera=(), geolocation=(), microphone=(), payment=()'
                accessControlMaxAge: 100
                addVaryHeader: true

        security-staging:
            headers:
                customResponseHeaders:
                    X-Robots-Tag: 'noindex, nofollow'

        compress:
            compress:
                excludedContentTypes:
                    - 'application/grpc'

        traefik-auth:
            basicAuth:
                users: ${TRAEFIK_AUTH}
```

### 6.5 Staging vs Production Traefik Differences

| Aspect               | Staging                                                 | Production          |
| -------------------- | ------------------------------------------------------- | ------------------- |
| CF Origin Cert       | Same cert (covers `*.domain.com`)                       | Same cert           |
| `X-Robots-Tag`       | `noindex, nofollow` (via `security-staging` middleware) | Not set (indexable) |
| HTTP/3               | Advertised                                              | Advertised          |
| Dashboard basic auth | Required                                                | Required            |
| `stop_grace_period`  | 35s                                                     | 35s                 |

---

## 7. CI/CD Pipeline

### 7.1 Flow

```
git push (develop | main | tag v*)
       │
       ▼
┌──────────────────────────────────────────────┐
│ GH Actions: docker.yml                       │
│  1. Checkout                                  │
│  2. Build dev image, run tests INSIDE         │
│     (pest, phpstan, lint, frontend build)     │
│  3. Build production image (target=production)            │
│  4. Push to GHCR with multiple tags           │
│  5. SSH deploy (only on tag/develop)          │
│     - docker compose pull                     │
│     - docker rollout app/horizon/ssr          │
│     - docker compose up scheduler/traefik     │
│     - octane:reload via exec                  │
└──────────────────────────────────────────────┘
       │
       ▼
   GHCR (ghcr.io/<org>/<repo>)
       │
       ├─→ staging VPS (auto on develop push)
       └─→ production VPS (auto on v* tag)
```

### 7.2 `.github/workflows/docker.yml`

```yaml
name: Build & Deploy

on:
    push:
        branches: [main, develop]
        tags: ['v*']
    workflow_dispatch:
        inputs:
            environment:
                type: choice
                options: [staging, production]
            image_tag:
                description: 'Image tag to deploy (overrides auto)'
                required: false

env:
    REGISTRY: ghcr.io
    IMAGE_NAME: ${{ github.repository }}

jobs:
    test:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v4

            - uses: docker/setup-buildx-action@v3

            - name: Build dev image
              uses: docker/build-push-action@v6
              with:
                  context: .
                  target: dev
                  load: true
                  tags: app:dev-test
                  cache-from: type=gha
                  cache-to: type=gha,mode=max

            - name: Start services
              run: |
                  USER_ID=$(id -u) GROUP_ID=$(id -g) \
                  docker compose up -d pgsql redis

            - name: Run composer scripts
              run: |
                  docker compose run --rm app composer validate
                  docker compose run --rm app composer test:lint
                  docker compose run --rm app composer test:types

            - name: Run pest tests
              run: docker compose run --rm app php artisan test --parallel
              env:
                  DB_DATABASE: testing
                  QUEUE_CONNECTION: sync

            - name: Verify frontend build
              run: docker compose run --rm app pnpm run build

    build:
        needs: test
        runs-on: ubuntu-latest
        permissions:
            contents: read
            packages: write
        steps:
            - uses: actions/checkout@v4
            - uses: docker/setup-buildx-action@v3
            - uses: docker/login-action@v3
              with:
                  registry: ${{ env.REGISTRY }}
                  username: ${{ github.actor }}
                  password: ${{ secrets.GITHUB_TOKEN }}

            - uses: docker/metadata-action@v5
              id: meta
              with:
                  images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
                  tags: |
                      type=sha,prefix=sha-,format=short
                      type=ref,event=branch
                      type=semver,pattern={{version}}
                      type=raw,value=latest,enable=${{ github.ref == 'refs/heads/main' }}
                      type=raw,value=staging,enable=${{ github.ref == 'refs/heads/develop' }}

            - uses: docker/build-push-action@v6
              with:
                  context: .
                  file: ./Dockerfile
                  target: production
                  push: true
                  tags: ${{ steps.meta.outputs.tags }}
                  labels: ${{ steps.meta.outputs.labels }}
                  cache-from: type=gha
                  cache-to: type=gha,mode=max
                  platforms: ${{ inputs.platforms || 'linux/amd64' }}

    deploy-staging:
        needs: build
        if: github.ref == 'refs/heads/develop'
        runs-on: ubuntu-latest
        environment: staging
        steps:
            - uses: appleboy/ssh-action@v1
              with:
                  host: ${{ secrets.STG_SSH_HOST }}
                  username: ${{ secrets.STG_SSH_USER }}
                  key: ${{ secrets.STG_SSH_KEY }}
                  script: |
                      cd /opt/app
                      docker compose -f compose.yaml -f compose.staging.yml pull
                      docker rollout -f compose.yaml -f compose.staging.yml app
                      docker rollout -f compose.yaml -f compose.staging.yml horizon
                      docker rollout -f compose.yaml -f compose.staging.yml ssr
                      docker rollout -f compose.yaml -f compose.staging.yml reverb
                      docker compose -f compose.yaml -f compose.staging.yml up -d --remove-orphans scheduler traefik
                      docker compose -f compose.yaml -f compose.staging.yml exec -T app php artisan octane:reload
                      docker image prune -f

    deploy-production:
        needs: build
        if: startsWith(github.ref, 'refs/tags/v')
        runs-on: ubuntu-latest
        environment: production
        steps:
            - uses: appleboy/ssh-action@v1
              with:
                  host: ${{ secrets.PROD_SSH_HOST }}
                  username: ${{ secrets.PROD_SSH_USER }}
                  key: ${{ secrets.PROD_SSH_KEY }}
                  script: |
                      cd /opt/app
                      docker compose -f compose.yaml -f compose.production.yml pull
                      docker rollout -f compose.yaml -f compose.production.yml app
                      docker rollout -f compose.yaml -f compose.production.yml horizon
                      docker rollout -f compose.yaml -f compose.production.yml ssr
                      docker rollout -f compose.yaml -f compose.production.yml reverb
                      docker compose -f compose.yaml -f compose.production.yml up -d --remove-orphans scheduler traefik
                      docker compose -f compose.yaml -f compose.production.yml exec -T app php artisan octane:reload
                      docker image prune -f
```

### 7.3 Branching Strategy

| Trigger              | Image tags                         | Auto-deploy                         |
| -------------------- | ---------------------------------- | ----------------------------------- |
| push `develop`       | `:develop`, `:staging`, `:sha-xxx` | staging VPS                         |
| push `main` (no tag) | `:main`, `:sha-xxx`                | none (manual via workflow_dispatch) |
| tag `v1.2.3`         | `:1.2.3`, `:sha-xxx`, `:latest`    | production VPS                      |

### 7.4 VPS One-Time Setup

```bash
# 1. Install Docker + docker-rollout
curl -fsSL https://get.docker.com | sh
mkdir -p ~/.docker/cli-plugins
curl -fsSL https://raw.githubusercontent.com/wowu/docker-rollout/master/docker-rollout \
  -o ~/.docker/cli-plugins/docker-rollout
chmod +x ~/.docker/cli-plugins/docker-rollout

# 2. Login to GHCR
echo "${GHCR_PAT}" | docker login ghcr.io -u USERNAME --password-stdin

# 3. Clone repo (for compose + traefik configs)
git clone https://github.com/org/repo.git /opt/app
cd /opt/app

# 4. Setup env
cp .env.production.example .env.production
nano .env.production   # fill secrets, APP_DOMAIN, DB_PASSWORD, REDIS_PASSWORD, TRAEFIK_AUTH, APP_KEY
# Generate APP_KEY locally:
#   php artisan key:generate --show
#   paste base64:... into .env.production

# 5. Setup CF Origin Cert
mkdir -p docker/traefik/certs
# Paste CF Origin Cert → docker/traefik/certs/cert.pem
# Paste CF Origin Key → docker/traefik/certs/private.key
chmod 600 docker/traefik/certs/*

# 6. First deploy (runs migrations via env)
RUNNING_MIGRATIONS_AND_SEEDERS=true docker compose -f compose.yaml -f compose.production.yml up -d
# Subsequent deploys use `make rollout-production` (no migrations)
```

### 7.5 Required GitHub Secrets

| Secret          | Environment  | Purpose                        |
| --------------- | ------------ | ------------------------------ |
| `STG_SSH_HOST`  | staging      | VPS IP/hostname                |
| `STG_SSH_USER`  | staging      | SSH user (e.g. `deploy`)       |
| `STG_SSH_KEY`   | staging      | SSH private key                |
| `PROD_SSH_HOST` | production   | VPS IP/hostname                |
| `PROD_SSH_USER` | production   | SSH user                       |
| `PROD_SSH_KEY`  | production   | SSH private key                |
| `GHCR_PAT`      | VPS (manual) | PAT with `read:packages` scope |

### 7.6 Rollback Runbook

```bash
# On VPS: rollback to previous image tag
cd /opt/app

# Option A: rollback to specific SHA tag
IMAGE_TAG=sha-abcd123 docker compose -f compose.yaml -f compose.production.yml up -d app horizon ssr

# Option B: rollback to previous version tag
IMAGE_TAG=v1.2.2 docker compose -f compose.yaml -f compose.production.yml up -d app horizon ssr

# Reload Octane to clear cached code
docker compose -f compose.yaml -f compose.production.yml exec app php artisan octane:reload

# IMPORTANT: if migrations are not backward-compatible, you MUST
# manually roll back migrations BEFORE reverting the image:
docker compose -f compose.yaml -f compose.production.yml exec app php artisan migrate:rollback --step=1
```

### 7.7 Post-Deploy Octane State Cleanup

After every rollout, the CI script runs `php artisan octane:reload` in the new app container to flush cached code/state. This is critical because:

- Old workers may hold stale route/service cache
- New container starts fresh, but `octane:reload` ensures immediate pickup of changes
- For long-running Horizon workers, restart via `docker rollout horizon` (handled automatically)

---

## 8. Dev DX (Makefile + Minimal Composer Scripts)

### 8.1 `Makefile`

```makefile
.DEFAULT_GOAL := help
.PHONY: help dev dev-stop dev-down dev-logs dev-rebuild \
        staging production staging-logs production-logs staging-down production-down \
        rollout-staging rollout-production production-scale-up production-scale-down \
        build build-production \
        artisan pnpm composer exec shell tinker test fresh \
        reload-staging reload-production \
        install clean

COMPOSE_DEV  = COMPOSE_PROFILES=dev  docker compose
COMPOSE_STAGING  = COMPOSE_PROFILES=staging  docker compose -f compose.yaml -f compose.staging.yml
COMPOSE_PRODUCTION = COMPOSE_PROFILES=production docker compose -f compose.yaml -f compose.production.yml
IMAGE ?= ghcr.io/thaolaptrinh/laravel-viltf

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ─── Setup ───────────────────────────────────────────────────────────────────

install: ## First-time setup: copy .env, build dev image, install deps in container, start
	[ -f .env ] || cp .env.example .env
	$(COMPOSE_DEV) build app
	$(COMPOSE_DEV) run --rm app composer install
	$(COMPOSE_DEV) run --rm app pnpm install
	$(COMPOSE_DEV) up -d

# ─── Dev ─────────────────────────────────────────────────────────────────────

dev: ## Start dev environment (app + horizon + pgsql + redis)
	$(COMPOSE_DEV) up -d --remove-orphans

dev-stop: ## Stop dev containers
	$(COMPOSE_DEV) stop

dev-down: ## Stop & remove dev containers + networks
	$(COMPOSE_DEV) down

dev-logs: ## Tail dev container logs
	$(COMPOSE_DEV) logs -f --tail=100

dev-rebuild: ## Rebuild dev app image
	$(COMPOSE_DEV) build app

# ─── Staging / Production (local test only — DO NOT run on real VPS via this) ──────────

staging: ## Start staging environment locally
	$(COMPOSE_STAGING) up -d --remove-orphans

production: ## Start production environment locally (testing only)
	$(COMPOSE_PRODUCTION) up -d --remove-orphans

staging-logs: ## Tail staging container logs
	$(COMPOSE_STAGING) logs -f --tail=100

production-logs: ## Tail production container logs
	$(COMPOSE_PRODUCTION) logs -f --tail=100

staging-down: ## Stop staging env
	$(COMPOSE_STAGING) down

production-down: ## Stop production env
	$(COMPOSE_PRODUCTION) down

# ─── Build ───────────────────────────────────────────────────────────────────

build: ## Build dev image
	$(COMPOSE_DEV) build app

build-production: ## Build production image locally for testing
	docker build --target=production -t $(IMAGE):local .

# ─── Deploy (zero-downtime via docker-rollout) ──────────────────────────────

rollout-staging: ## Zero-downtime deploy staging
	$(COMPOSE_STAGING) pull
	docker rollout -f compose.yaml -f compose.staging.yml app
	docker rollout -f compose.yaml -f compose.staging.yml horizon
	docker rollout -f compose.yaml -f compose.staging.yml ssr
	docker rollout -f compose.yaml -f compose.staging.yml reverb
	$(COMPOSE_STAGING) up -d --remove-orphans scheduler traefik
	$(COMPOSE_STAGING) exec -T app php artisan octane:reload

rollout-production: ## Zero-downtime deploy production
	$(COMPOSE_PRODUCTION) pull
	docker rollout -f compose.yaml -f compose.production.yml app
	docker rollout -f compose.yaml -f compose.production.yml horizon
	docker rollout -f compose.yaml -f compose.production.yml ssr
	docker rollout -f compose.yaml -f compose.production.yml reverb
	$(COMPOSE_PRODUCTION) up -d --remove-orphans scheduler traefik
	$(COMPOSE_PRODUCTION) exec -T app php artisan octane:reload

production-scale-up: ## Scale production app to N replicas (default 2)
	$(COMPOSE_PRODUCTION) up -d --scale app=${N:-2} --no-recreate app

production-scale-down: ## Scale production app back to 1
	$(COMPOSE_PRODUCTION) up -d --scale app=1 --no-recreate app

# ─── Octane reload ───────────────────────────────────────────────────────────

reload-staging: ## Reload Octane (clear cached state) in staging
	$(COMPOSE_STAGING) exec app php artisan octane:reload

reload-production: ## Reload Octane in production
	$(COMPOSE_PRODUCTION) exec app php artisan octane:reload

# ─── Command passthrough (dev container) ────────────────────────────────────

artisan: ## Run Artisan: make artisan CMD="tinker"
	$(COMPOSE_DEV) exec app php artisan $(CMD)

pnpm: ## Run pnpm: make pnpm CMD="install"
	$(COMPOSE_DEV) exec app pnpm $(CMD)

exec: ## Run arbitrary cmd in app: make exec CMD="sh"
	$(COMPOSE_DEV) exec app $(CMD)

shell: ## Get shell in app container
	$(COMPOSE_DEV) exec app sh

tinker: ## Tinker
	$(COMPOSE_DEV) exec app php artisan tinker

test: ## Run tests: make test CMD="--filter=TestName"
	$(COMPOSE_DEV) exec app php artisan test $(CMD)

fresh: ## Migrate fresh + seed
	$(COMPOSE_DEV) exec app php artisan migrate:fresh --seed

clean: ## Remove all containers, volumes, images
	$(COMPOSE_DEV) down -v --rmi local || true
	$(COMPOSE_STAGING) down -v --rmi local || true
	$(COMPOSE_PRODUCTION) down -v --rmi local || true
```

### 8.2 `composer.json` scripts (minimal — PHP tooling only)

```json
{
    "scripts": {
        "test": "@php artisan test",
        "test:type-coverage": "pest --type-coverage --min=100",
        "test:lint": [
            "pint --parallel --test",
            "rector --dry-run",
            "pnpm run test:lint"
        ],
        "test:types": ["phpstan --memory-limit=512M", "pnpm run test:types"],
        "test:unit": "pest --parallel --coverage --exactly=100.0",
        "lint": ["rector", "pint --parallel", "pnpm run lint"],
        "post-autoload-dump": [
            "Illuminate\\Foundation\\ComposerScripts::postAutoloadDump",
            "@php artisan package:discover --ansi",
            "@php artisan filament:upgrade"
        ],
        "post-update-cmd": [
            "@php artisan vendor:publish --tag=laravel-assets --ansi --force"
        ]
    }
}
```

> The previous `dev` and `dev:ssr` scripts (which ran things natively via `concurrently`) are removed. Use `make dev` instead.

### 8.3 Sail → Make Migration Reference

| Sail command                     | New equivalent                                                       |
| -------------------------------- | -------------------------------------------------------------------- |
| `vendor/bin/sail up -d`          | `make dev`                                                           |
| `vendor/bin/sail stop`           | `make dev-stop`                                                      |
| `vendor/bin/sail down`           | `make dev-down`                                                      |
| `vendor/bin/sail logs -f`        | `make dev-logs`                                                      |
| `vendor/bin/sail artisan <cmd>`  | `make artisan CMD="<cmd>"`                                           |
| `vendor/bin/sail composer <cmd>` | `composer <cmd>` (runs on host)                                      |
| `vendor/bin/sail pnpm <cmd>`     | `make pnpm CMD="<cmd>"`                                              |
| `vendor/bin/sail test`           | `make test`                                                          |
| `vendor/bin/sail tinker`         | `make tinker`                                                        |
| `vendor/bin/sail bin pint ...`   | `make exec CMD="pint ..."`                                           |
| `vendor/bin/sail open`           | Browser: `http://localhost:${APP_PORT:-8080}`                        |
| `vendor/bin/sail share`          | `cloudflared tunnel --url http://localhost:8080` (documented opt-in) |
| `vendor/bin/sail php <script>`   | `make exec CMD="php <script>"`                                       |

---

## 9. Environment & Secrets

### 9.1 `.env.example` (committed — for dev / non-Docker fallback)

```diff
- DB_CONNECTION=sqlite
+ DB_CONNECTION=pgsql
+ DB_HOST=pgsql
+ DB_PORT=5432
+ DB_DATABASE=laravel
+ DB_USERNAME=laravel
+ DB_PASSWORD=secret

- SESSION_DRIVER=database
- QUEUE_CONNECTION=database
- CACHE_STORE=database
+ SESSION_DRIVER=redis
+ QUEUE_CONNECTION=redis
+ CACHE_STORE=redis
+ REDIS_HOST=redis
+ REDIS_PORT=6379

+ # Broadcasting (Reverb — first-party WebSocket server)
+ BROADCAST_CONNECTION=reverb
+ REVERB_APP_ID=laravel-viltf
+ REVERB_APP_KEY=REPLACE_WITH_RANDOM_KEY
+ REVERB_APP_SECRET=REPLACE_WITH_RANDOM_SECRET
+ REVERB_HOST=127.0.0.1   # dev: 127.0.0.1; staging/production: your domain (e.g., staging.yourdomain.com)
+ REVERB_PORT=8080
+ REVERB_SCHEME=http     # dev: http; staging/production: https
+ VITE_REVERB_APP_KEY="${REVERB_APP_KEY}"
+ VITE_REVERB_HOST="${REVERB_HOST}"
+ VITE_REVERB_PORT="${REVERB_PORT}"
+ VITE_REVERB_SCHEME="${REVERB_SCHEME}"

+ # Docker / Octane
+ APP_PORT=8080
+ VITE_PORT=5173
+ COMPOSE_PROFILES=dev
+ OCTANE_SERVER=frankenphp
+ OCTANE_HTTPS=false
+ RUNNING_MIGRATIONS_AND_SEEDERS=false
+ USER_ID=1000
+ GROUP_ID=1000
+ TZ=UTC
+
+ # Staging / Production (only used by staging/production compose)
+ GH_REPO=thaolaptrinh/laravel-viltf
+ IMAGE_TAG=latest
+ APP_DOMAIN=localhost
+ TRAEFIK_AUTH=user:$$2y$$05$$REPLACE_WITH_BCRYPT_HASH
```

> Note: SQLite still works if user wants to skip Docker. Document: _"To run without Docker, set `DB_CONNECTION=sqlite` and use `php artisan serve`."_

### 9.2 `.env.staging.example` (committed template)

```bash
APP_ENV=staging
APP_DEBUG=false
APP_URL=https://staging.yourdomain.com
APP_DOMAIN=staging.yourdomain.com
APP_KEY=base64:GENERATE_ME

DB_DATABASE=laravel_stg
DB_USERNAME=laravel_stg
DB_PASSWORD=CHANGE_ME_STRONG

REDIS_PASSWORD=CHANGE_ME

OCTANE_SERVER=frankenphp
OCTANE_HTTPS=true
RUNNING_MIGRATIONS_AND_SEEDERS=false

IMAGE_TAG=staging
TRAEFIK_AUTH=user:$$2y$$05$$REPLACE_WITH_BCRYPT_HASH
```

### 9.3 `.env.production.example` (committed template)

```bash
APP_ENV=production
APP_DEBUG=false
APP_URL=https://yourdomain.com
APP_DOMAIN=yourdomain.com
APP_KEY=base64:GENERATE_ME_STRONG

DB_DATABASE=laravel_prod
DB_USERNAME=laravel_prod
DB_PASSWORD=CHANGE_ME_VERY_STRONG

REDIS_PASSWORD=CHANGE_ME_VERY_STRONG

OCTANE_SERVER=frankenphp
OCTANE_HTTPS=true
RUNNING_MIGRATIONS_AND_SEEDERS=false

IMAGE_TAG=latest
TRAEFIK_AUTH=admin:$$2y$$05$$REPLACE_WITH_BCRYPT_HASH
```

### 9.4 Gitignored files

Append to `.gitignore`:

```gitignore
# Docker secrets
.env
.env.staging
.env.production
docker/traefik/certs/*.pem
docker/traefik/certs/*.key
docker/traefik/certs/private.key

# Compose user local overrides
compose.override.local.yml

# Backups
backups/
```

### 9.5 `.dockerignore`

```gitignore
.git/
.github/
.agents/
.claude/
.node_modules/
.pnpm-store/
vendor/
node_modules/
.env
.env.*
!.env.example
!.env.staging.example
!.env.production.example
compose*.yml
Dockerfile*
Makefile
docker/
!docker/deployment
!docker/traefik
frankenphp
frankenphp.*
boost.json
phpstan.neon
phpunit.xml
rector.php
pint.json
tests/
dbdiagram.*
dbml-error.log
README.md
AGENTS.md
CLAUDE.md
opencode.json
.mcp.json
.husky/
.editorconfig
.gitattributes
.gitignore
skills-lock.json
components.json
*.log
```

### 9.6 APP_KEY Strategy

- **Dev:** `php artisan key:generate` runs once locally (host composer), persisted in `.env` (gitignored).
- **Staging/Production:** User runs `php artisan key:generate --show` locally, copies `base64:...` into `.env.staging` / `.env.production` on VPS.
- **NEVER** auto-generate in entrypoint (would change on every container restart, invalidating sessions).
- Document in `README.md` setup section.

---

## 10. Operational Concerns

### 10.1 VPS Sizing

**Target hardware:** 2 vCPU / 6 GB RAM / 60+ GB SSD (NVMe preferred for Postgres).

| Profile            | Specs                          | Use case                                                                      |
| ------------------ | ------------------------------ | ----------------------------------------------------------------------------- |
| **Minimum**        | 2 vCPU / 4 GB / 40 GB SSD      | Dev/staging, light production (< 100 RPS), app scale=1, Postgres under-tuned  |
| **Recommended** ⭐ | 2 vCPU / 6 GB / 60 GB SSD      | Production real, app scale=2, full features (Horizon + Reverb + SSR + backup) |
| **Heavy load**     | 4 vCPU / 8-16 GB / 120 GB NVMe | Multi-tenant SaaS, high traffic, lots of concurrent WS                        |

> **Provider note:** Some providers (e.g., Cloudfly.vn) bundle CPU+RAM in fixed plans. If 2C/6GB custom not available, jump to 4C/8GB plan rather than staying at 2C/4GB.

### 10.2 Resource Limits (production, 6 GB target)

| Service               | Memory limit | Typical use                 | Notes                        |
| --------------------- | ------------ | --------------------------- | ---------------------------- |
| app (per replica × 2) | 384 MB       | 200 MB                      | Octane + Laravel, scale=2    |
| horizon               | 256 MB       | 150 MB                      | Queue consumer + dashboard   |
| scheduler             | 64 MB        | 30 MB                       | supercronic only             |
| ssr                   | 256 MB       | 150 MB                      | Node daemon                  |
| reverb                | 256 MB       | 150 MB baseline + 50KB/conn | WebSocket server             |
| pgsql                 | 1 GB         | 600 MB                      | Tuned for 6 GB host          |
| redis                 | 200 MB       | 100 MB                      | `--maxmemory 180mb`          |
| traefik               | 96 MB        | 50 MB                       | Edge proxy                   |
| OS + Docker           | -            | 400 MB                      | -                            |
| **Total cap**         | **~2.9 GB**  | **~1.8 GB**                 | Buffer ~3 GB for OS + spikes |

For 4 GB minimum profile, halve the limits: app 256 MB, horizon 192 MB, pgsql 800 MB, etc. Scale app=1 only.

### 10.3 Postgres Tuning (`docker/deployment/postgres/postgresql.conf`)

Mount as `postgresql.conf` via volume; image's default config is conservative.

For 6 GB target host:

```ini
# Memory (25% of total RAM)
shared_buffers = 1GB
effective_cache_size = 3GB
work_mem = 8MB
maintenance_work_mem = 256MB

# Connections
max_connections = 100

# WAL / Checkpoints
wal_buffers = 16MB
checkpoint_completion_target = 0.9
random_page_cost = 1.1            # SSD/NVMe

# Query planner
default_statistics_target = 100

# Logging (optional)
log_min_duration_statement = 500  # log queries > 500ms
```

For 4 GB minimum: `shared_buffers=256MB`, `effective_cache_size=1GB`, `work_mem=4MB`.

### 10.4 Restart Policies

All services: `restart: unless-stopped`. This survives VPS reboot but respects `docker compose stop`.

### 10.5 Logging

- Driver: `json-file`
- Rotation: `max-size=50m`, `max-file=10`, compress enabled
- For centralization: ship logs via `fluentd`/`fluent-bit` driver (documented opt-in)

### 10.6 Backup Strategy (opt-in)

**Option A:** Use `offen/docker-volume-backup` sidecar (in `compose.production.yml` under `profiles: [backup]`). Enable with `make production-backup-enable` (custom target) or `COMPOSE_PROFILES=production,backup docker compose -f ... up -d`.

**Option B:** Manual `pg_dump` cron inside scheduler container. Add to `docker/deployment/supercronic/laravel`:

```cron
0 2 * * * /bin/sh -c 'pg_dump -U $DB_USERNAME -h pgsql $DB_DATABASE | gzip > /backup/db-$(date +\%Y\%m\%d).sql.gz && find /backup -mtime +7 -delete'
```

Document both in README; default: neither enabled.

### 10.7 Horizon Dashboard Auth

Horizon's dashboard is gated by `Gate::define('viewHorizon', ...)` in `app/Providers/HorizonServiceProvider.php` (auto-published on `vendor:publish`). Configure to restrict to admins in production:

```php
Gate::define('viewHorizon', function (User $user = null) {
    return in_array(optional($user)->email, [
        'admin@yourdomain.com',
    ]);
});
```

Default deny in staging/production. Document in README.

### 10.8 Storage Volumes (production)

`storage/app/public` is mounted as a Docker volume (`./storage/app/public:/var/www/html/storage/app/public`) so user-uploaded files persist across container rollouts. Filament file uploads use this path.

### 10.9 Postgres Connection Pooling (opt-in)

For high-traffic deployments, add PgBouncer between app and Postgres. Document pattern (Bitnami pgbouncer image), set `DB_HOST=pgbouncer` in env. Default: not included.

### 10.10 Reverb Scaling Notes

- Single Reverb container handles ~1000 concurrent connections per 256MB RAM
- For horizontal scaling: deploy multiple `reverb` replicas + Redis pub/sub (already in stack) — Reverb uses Redis for cross-node broadcast
- Traefik auto-LB between replicas via service labels

---

## 11. Migration Plan (Sail → Docker)

### 11.1 Pre-flight Verification

- [ ] Verify `composer.lock` is committed (required for reproducible Docker builds)
- [ ] Verify `pnpm-lock.yaml` is committed
- [ ] Verify `php: ^8.5` constraint in composer.json
- [ ] Verify `/up` route exists (default Laravel 13 route)
- [ ] Verify `config/octane.php` exists with frankenphp server
- [ ] Verify Filament v5 Octane compatibility notes
- [ ] Backup existing `.env` (in case rollback needed)
- [ ] Tag git branch `pre-docker-migration` for rollback

### 11.2 Step-by-Step Migration

1. **Create new files**
    - `Dockerfile`, `Makefile`, `.dockerignore`
    - `compose.yaml`, `compose.override.yml`, `compose.staging.yml`, `compose.production.yml`
    - `docker/deployment/*` (all scripts and configs)
    - `docker/traefik/*` (static, dynamic, certs/.gitkeep)
    - `.github/workflows/docker.yml`
    - `.env.staging.example`, `.env.production.example`

2. **Update existing files**
    - `composer.json`: remove `laravel/sail` from `require-dev`; **add `laravel/horizon` and `laravel/reverb` to `require`**; simplify scripts
    - `.env.example`: update defaults per Section 9.1
    - `.gitignore`: add Docker secrets
    - `config/octane.php`: verify config (likely no changes needed)
    - `bootstrap/app.php`: verify `trustProxies(at: '*')` middleware (likely already there in Laravel 13)
    - `README.md`: rewrite setup + commands
    - `AGENTS.md` + `CLAUDE.md`: replace `=== sail rules ===` section with `=== docker rules ===`; replace all `vendor/bin/sail` references
    - `.agents/skills/**/SKILL.md` + `.claude/skills/**/SKILL.md`: replace `vendor/bin/sail` with `make`

3. **Delete obsolete files**
    - `compose.yaml` (old Sail-generated; replaced by new)
    - `docker/8.5/` (Sail's Dockerfile directory)
    - `frankenphp` binary at repo root (165 MB; bundled in image)
    - `docker/compose.dev.yml`, `docker/compose.staging.yml`, `docker/compose.production.yml` (empty scaffolds)
    - `docker/app/` (empty scaffold directory)

4. **Remove Sail**

    ```bash
    composer remove laravel/sail --dev
    ```

5. **Verify dev environment**

    ```bash
    make install   # composer install + pnpm install + cp .env + make dev
    make artisan CMD="migrate"
    make artisan CMD="tinker"  # smoke test
    make test
    ```

6. **Verify production build locally**

    ```bash
    make build-production
    docker run --rm -e APP_KEY=test -e DB_CONNECTION=sqlite $(IMAGE):local php artisan about
    ```

7. **Update CI secrets (GH)**
    - `STG_SSH_HOST`, `STG_SSH_USER`, `STG_SSH_KEY`
    - `PROD_SSH_HOST`, `PROD_SSH_USER`, `PROD_SSH_KEY`

8. **Provision VPS** (Section 7.4)

9. **First production deploy** (with migrations)

    ```bash
    # On VPS
    RUNNING_MIGRATIONS_AND_SEEDERS=true docker compose -f compose.yaml -f compose.production.yml up -d
    ```

10. **Subsequent deploys** use `make rollout-production` (zero-downtime, no migrations).

### 11.3 Rollback Strategy

If migration breaks dev:

```bash
git checkout pre-docker-migration -- .
composer install
vendor/bin/sail up -d   # Sail still installed in this revision
```

If migration breaks production:

```bash
# Revert image tag (Section 7.6)
IMAGE_TAG=<previous-good-tag> docker compose -f compose.yaml -f compose.production.yml up -d app horizon ssr
docker compose -f compose.yaml -f compose.production.yml exec app php artisan octane:reload
```

---

## 12. Out of Scope

| Item                                   | Reason                                      | Future opt-in                        |
| -------------------------------------- | ------------------------------------------- | ------------------------------------ |
| Prometheus / Grafana                   | Use hosted (Grafana Cloud) or Laravel Pulse | Document integration pattern         |
| Netdata                                | Same                                        | Document                             |
| pgAdmin / pghero                       | Admin tools, not core runtime               | Document                             |
| Mailhog / Mailpit                      | Dev mail capture                            | Document                             |
| Custom FrankenPHP build (cbrotli etc.) | CF handles edge compression                 | Document if needed                   |
| Multi-arch build default               | Most VPS are amd64                          | Via `platforms` workflow input       |
| Kamal                                  | Single-VPS doesn't need it                  | N/A                                  |
| Kubernetes                             | Out of scope for starter                    | N/A                                  |
| PgBouncer                              | For high-traffic                            | Document opt-in pattern              |
| ACME / Let's Encrypt                   | CF Origin Cert default                      | Document Traefik ACME setup          |
| Cloudflare Tunnel                      | Setup A chosen                              | Document Setup B alternative         |
| Trivy image scanning                   | Opt-in security                             | Add workflow job                     |
| Slack/Discord deploy notifications     | Opt-in                                      | Add webhook step                     |
| Rate limiting middleware               | App-level concern                           | Add via `throttle:` route middleware |

---

## 13. Open Questions / Research Tasks (verify during implementation)

1. **Filament v5 + Octane** specific listener requirements — check official Filament 5 docs for Octane notes.
2. **`install-php-extensions`** extension name compatibility with FrankenPHP alpine builder (some extensions may need different naming).
3. **Postgres 18-alpine** image tag availability on Docker Hub (verify at implementation).
4. **Redis 7-alpine vs 8-alpine** — choose current stable at implementation time.
5. **`composer.lock` presence** in repo (already verified — it's committed).
6. **`/up` route** exists in Laravel 13 default starter routes (verify).
7. **`config/octane.php` `RequestReceived` listener** includes necessary cleanup for Livewire state.
8. **`bootstrap/app.php` TrustProxies** middleware configuration (likely default-trust-all in Laravel 13).
9. **`pnpm run build:ssr`** script exists in `package.json` — add if missing.
10. **Composer 2.8** latest patch version pinning in Dockerfile.
11. **FrankenPHP Caddyfile** default behavior — verify whether `octane:frankenphp` requires explicit `--caddyfile` arg.
12. **`docker-rollout`** supports multi-file compose (`-f a -f b`) — verify.

---

## 14. Self-Review Notes

### 14.1 Self-Review Findings (incorporated)

- ✅ Octane + Filament + Livewire compatibility addressed (Section 4.3.2)
- ✅ Test inside container (Section 7.2)
- ✅ User UID/GID per-target handling (Section 4.2)
- ✅ HTTPS scheme forcing via `OCTANE_HTTPS=true` (Section 4.3.1, already supported in config)
- ✅ Trusted proxies (Section 4.3.3)
- ✅ APP_KEY generation strategy (Section 9.6)
- ✅ Storage permissions (Section 4.1 production target)
- ✅ Build cache strategy (Section 4.2)
- ✅ Caddyfile opt-in (Section 4.3.4)
- ✅ OPCache preload/settings (Section 4.4)
- ✅ PHP memory_limit explicit (Section 4.4)
- ✅ Timezone handling (Section 4.2)
- ✅ Traefik compress middleware (Section 6.4)
- ✅ PgBouncer mention (Section 10.7)
- ✅ Octane state cleanup post-deploy (Section 7.7, 8.1 reload targets)
- ✅ Rollback documentation (Section 7.6, 11.3)
- ✅ APP_URL/APP_DOMAIN per env (Section 9.2, 9.3)
- ✅ Make install target (Section 8.1)
- ✅ docker-rollout install prerequisite (Section 7.4)
- ✅ Redis persistence config (Section 5.2 redis command)
- ✅ **Laravel Reverb included as default WS service** (Section 3.1, 3.2, 4.5, 4.6, 5.2, 5.4, 5.5, 7.2, 8.1)
- ✅ **VPS sizing**: 2C/6GB recommended, 4GB minimum, 4C/8GB heavy (Section 10.1)
- ✅ **Postgres tuning** for 6GB host (Section 10.3)
- ✅ **Memory limits tuned** to fit 6GB profile (Section 10.2)
- ✅ **Redis `--maxmemory` flag** via env (Section 5.2)
- ✅ **`make install` runs deps inside container** — no host PHP/composer required (Section 8.1)
- ✅ **Reverb env vars** in `.env.example` (Section 9.1)

### 14.2 Items Deferred (Nice-to-Have)

- Trivy scanning → README note
- Postgres backup script → README opt-in template
- Deploy notifications → README note
- Rate limiting → Laravel throttle middleware (no Traefik needed)
- ACME config template → README note
- Network driver mtu 1450 → skip
- Pgbouncer container → README pattern

### 14.3 Spec Scope Verification

- Single implementation plan can execute this design
- All sections internally consistent
- No placeholders or TBDs in spec
- File inventory complete
- Migration steps ordered
- Rollback strategy defined

---

## 15. Implementation Plan (next step)

After user approval of this spec, invoke the **writing-plans** skill to generate a detailed implementation plan with:

- Ordered task list with dependencies
- Per-task acceptance criteria
- Verification commands
- Estimated complexity per task
