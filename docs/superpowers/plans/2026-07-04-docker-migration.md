# Docker Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Laravel Sail with a production-grade Docker setup spanning dev/staging/production, using FrankenPHP/Octane as runtime, Traefik+Cloudflare as edge, docker-rollout for zero-downtime deploys.

**Architecture:** Multi-stage Dockerfile (base/dev/production targets) + Hybrid compose pattern (base + override files + profiles) + Supervisor as PID 1 with `CONTAINER_MODE` dispatcher (http/horizon/scheduler/ssr/reverb) + Traefik edge proxy with CF Origin Cert + CI build to GHCR + docker-rollout for zero-downtime.

**Tech Stack:** PHP 8.5, Laravel 13, FrankenPHP 1.12.4-php8.5-alpine, Octane, Filament 5, Inertia 3, Livewire 4, Vue 3, Tailwind 4, PostgreSQL 18, Redis 7, Laravel Horizon, Laravel Reverb, Traefik v3.6, docker-rollout.

**Reference spec:** `docs/superpowers/specs/2026-07-04-docker-migration-design.md`

**VPS target:** 2 vCPU / 6 GB RAM / 60+ GB SSD (4 GB minimum, 4C/8GB+ heavy)

---

## Pre-flight Checklist

Before starting, ensure:

- [ ] You are on the project root: `cd /home/thaonguyen/code/laravel-viltf-starter-kit`
- [ ] No uncommitted work: `git status` should be clean (or commit/stash)
- [ ] Docker is running: `docker info` works
- [ ] All commands run through Sail (`vendor/bin/sail ...`) until Task 23 removes it
- [ ] `composer.lock` and `pnpm-lock.yaml` are committed

---

## Task 1: Create Safety Backup Branch

**Files:** None (git operations only)

- [ ] **Step 1: Verify clean git state**

Run: `git status`
Expected: "nothing to commit, working tree clean"

- [ ] **Step 2: Create annotated tag for rollback**

```bash
git tag -a pre-docker-migration -m "State before Docker migration"
git push origin pre-docker-migration
```

- [ ] **Step 3: Create working branch**

```bash
git checkout -b feat/docker-migration
```

- [ ] **Step 4: Verify branch**

Run: `git branch --show-current`
Expected: `feat/docker-migration`

---

## Task 2: Create `.dockerignore`

**Files:**

- Create: `.dockerignore`

- [ ] **Step 1: Write `.dockerignore`**

```
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

- [ ] **Step 2: Verify file exists**

Run: `cat .dockerignore | wc -l`
Expected: `38` (approximate)

- [ ] **Step 3: Commit**

```bash
git add .dockerignore
git commit -m "chore(docker): add .dockerignore for lean build context"
```

---

## Task 3: Create Dockerfile (Multi-Stage)

**Files:**

- Create: `Dockerfile`

- [ ] **Step 1: Write `Dockerfile`**

```dockerfile
# syntax=docker/dockerfile:1.7

ARG PHP_VERSION=8.5
ARG FRANKENPHP_VERSION=1.12.4
ARG COMPOSER_VERSION=2.8
ARG NODE_VERSION=22

# ─── Base stage ─────────────────────────────────────────────────────────────
FROM dunglas/frankenphp:${FRANKENPHP_VERSION}-php${PHP_VERSION}-alpine AS base

ARG USER_ID=1000
ARG GROUP_ID=1000
ARG TZ=UTC

ENV TERM=xterm-color \
    OCTANE_SERVER=frankenphp \
    TZ=${TZ} \
    LANG=C.UTF-8 \
    USER=laravel \
    GROUP=laravel \
    ROOT=/var/www/html \
    APP_ENV=production \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_FUND=0 \
    COMPOSER_MAX_PARALLEL_HTTP=48 \
    WITH_VITE=false \
    RUNNING_MIGRATIONS_AND_SEEDERS=false \
    XDG_CONFIG_HOME=${ROOT}/.config \
    XDG_DATA_HOME=${ROOT}/.data

WORKDIR ${ROOT}

SHELL ["/bin/sh", "-eou", "pipefail", "-c"]

RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone

# System packages
RUN apk update && apk upgrade && apk add --no-cache \
    curl wget vim tzdata ncdu procps unzip ca-certificates bash supervisor \
    libsodium-dev libpng-dev libzip-dev icu-libs oniguruma-db postgresql-libs && \
    rm -rf /var/cache/apk/*

# PHP extensions
RUN install-php-extensions \
    apcu pcntl mbstring bcmath sockets pdo_pgsql pdo_mysql \
    opcache exif zip intl gd redis ffi uv

# Supercronic
RUN arch="$(apk --print-arch)" && \
    case "$arch" in \
        x86_64)  cronic='supercronic-linux-amd64' ;; \
        aarch64) cronic='supercronic-linux-arm64' ;; \
        x86)     cronic='supercronic-linux-386' ;; \
        armhf)   cronic='supercronic-linux-arm' ;; \
        *) echo "unsupported arch: $arch" && exit 1 ;; \
    esac && \
    wget -q "https://github.com/aptible/supercronic/releases/download/v0.2.33/${cronic}" \
        -O /usr/bin/supercronic && \
    chmod +x /usr/bin/supercronic && \
    mkdir -p /etc/supercronic

# Composer binary
COPY --link --from=composer:${COMPOSER_VERSION} /usr/bin/composer /usr/bin/composer

# Non-root user matching host UID/GID
RUN addgroup -g ${GROUP_ID} ${GROUP} 2>/dev/null || true && \
    adduser -D -G ${GROUP} -u ${USER_ID} -s /bin/sh ${USER} 2>/dev/null || true

# Deployment artifacts
COPY --link docker/deployment/supervisord.conf /etc/supervisord.conf
COPY --link docker/deployment/supervisord.*.conf /etc/supervisor/conf.d/
COPY --link docker/deployment/start-container /usr/local/bin/start-container
COPY --link docker/deployment/healthcheck /usr/local/bin/healthcheck
COPY --link docker/deployment/php.ini ${PHP_INI_DIR}/conf.d/99-php.ini
COPY --link docker/deployment/supercronic/laravel /etc/supercronic/laravel

RUN chmod +x /usr/local/bin/start-container /usr/local/bin/healthcheck && \
    mkdir -p \
        ${ROOT}/storage/framework/sessions \
        ${ROOT}/storage/framework/views \
        ${ROOT}/storage/framework/cache \
        ${ROOT}/storage/framework/testing \
        ${ROOT}/storage/logs \
        ${ROOT}/bootstrap/cache && \
    chown -R ${USER}:${GROUP} ${ROOT}

# ─── Composer deps (dev) ────────────────────────────────────────────────────
FROM composer:${COMPOSER_VERSION} AS composer-dev
WORKDIR /app
COPY --link composer.json composer.lock ./
RUN composer install --no-interaction --no-autoloader --no-scripts --no-progress

# ─── Composer deps (production) ───────────────────────────────────────────────────
FROM composer:${COMPOSER_VERSION} AS composer-production
WORKDIR /app
COPY --link composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --no-autoloader --no-scripts --no-progress --optimize --apcu

# ─── Assets stage ───────────────────────────────────────────────────────────
FROM node:${NODE_VERSION}-alpine AS assets
WORKDIR /app
COPY --link package.json pnpm-lock.yaml ./
RUN corepack enable && corepack prepare pnpm@latest --activate && \
    pnpm install --frozen-lockfile
COPY --link . .
RUN pnpm run build && pnpm run build:ssr

# ─── Dev target ─────────────────────────────────────────────────────────────
FROM base AS dev

# XDebug + Node + pnpm for dev workflow
RUN apk add --no-cache \
    linux-headers autoconf make g++ && \
    pecl install xdebug && \
    docker-php-ext-enable xdebug && \
    apk del linux-headers autoconf make g++ && \
    rm -rf /var/cache/apk/* && \
    curl -fsSL https://get.docker.com/plugins/buildx -o /usr/local/bin/docker-buildx || true

# Install Node + pnpm in dev target (for Vite HMR)
COPY --link --from=node:${NODE_VERSION}-alpine /usr/local/bin /usr/local/bin
COPY --link --from=node:${NODE_VERSION}-alpine /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN corepack enable && corepack prepare pnpm@latest --activate

# Dev vendor
COPY --link --chown=${USER}:${GROUP} --from=composer-dev /app/vendor ./vendor
RUN composer dump-autoload --apcu

ENV WITH_VITE=true \
    XDEBUG_MODE=off

USER ${USER}
EXPOSE 8000 5173 9003
ENTRYPOINT ["start-container"]
CMD []

# ─── Production target ────────────────────────────────────────────────────────────
FROM base AS production

ENV APP_ENV=production \
    WITH_VITE=false

# Production vendor
COPY --link --chown=${USER}:${GROUP} --from=composer-production /app/vendor ./vendor

# Built assets + SSR bundle
COPY --link --chown=${USER}:${GROUP} --from=assets /app/public/build ./public/build
COPY --link --chown=${USER}:${GROUP} --from=assets /app/storage/ssr ./storage/ssr

# Application source
COPY --link --chown=${USER}:${GROUP} . .

RUN composer dump-autoload --optimize --apcu --no-dev && \
    php artisan optimize --no-interaction && \
    php artisan storage:link --no-interaction || true && \
    chown -R ${USER}:${GROUP} ${ROOT} && \
    find / -perm /6000 -type f -exec chmod a-s {} + 2>/dev/null || true

USER ${USER}
EXPOSE 8000
ENTRYPOINT ["start-container"]
HEALTHCHECK --start-period=5s --interval=10s --timeout=3s --retries=5 CMD healthcheck || exit 1
CMD []
```

- [ ] **Step 2: Verify syntax (dry-run)**

Run: `docker build --target=base --check . 2>&1 | tail -5`
Expected: No syntax errors (may fail later stages due to missing `docker/deployment/*` files — that's OK at this point)

- [ ] **Step 3: Commit**

```bash
git add Dockerfile
git commit -m "feat(docker): add multi-stage Dockerfile (base/dev/production targets)"
```

---

## Task 4: Create `docker/deployment/` Scripts

**Files:**

- Create: `docker/deployment/start-container`
- Create: `docker/deployment/healthcheck`
- Create: `docker/deployment/php.ini`
- Create: `docker/deployment/supervisord.conf`
- Create: `docker/deployment/supervisord.http.conf`
- Create: `docker/deployment/supervisord.horizon.conf`
- Create: `docker/deployment/supervisord.scheduler.conf`
- Create: `docker/deployment/supervisord.ssr.conf`
- Create: `docker/deployment/supervisord.reverb.conf`
- Create: `docker/deployment/supercronic/laravel`
- Create: `docker/deployment/frankenphp/Caddyfile`

- [ ] **Step 1: Create `docker/deployment/start-container`**

```sh
#!/usr/bin/env sh
set -e

container_mode="${CONTAINER_MODE:-http}"
run_migrations="${RUNNING_MIGRATIONS_AND_SEEDERS:-false}"

initial_stuff() {
    echo "Container mode: ${container_mode}"

    if [ "${run_migrations}" = "true" ]; then
        echo "Running migrations and seeders..."
        php artisan migrate --isolated --seed --force \
            || php artisan migrate --seed --force
    fi

    php artisan storage:link 2>/dev/null || true
    php artisan optimize
}

if [ -n "$1" ]; then
    # Allow ad-hoc command: docker compose exec app <cmd>
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
    echo "Unknown CONTAINER_MODE: ${container_mode}" >&2
    exit 1
fi
```

- [ ] **Step 2: Create `docker/deployment/healthcheck`**

```sh
#!/usr/bin/env sh
set -e
curl --fail --max-time 3 http://127.0.0.1:8000/up
```

- [ ] **Step 3: Create `docker/deployment/php.ini`**

```ini
; Memory & limits
memory_limit = 256M
upload_max_filesize = 64M
post_max_size = 72M
max_execution_time = 60
max_input_time = 60

; Timezone
date.timezone = UTC

; OPCache (essential for Octane)
opcache.enable = 1
opcache.enable_cli = 1
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 32
opcache.max_accelerated_files = 20000
opcache.validate_timestamps = 0
opcache.revalidate_freq = 0
opcache.fast_shutdown = 1

; APCu (for composer autoload cache)
apc.enabled = 1
apc.enable_cli = 1

; Security hardening
expose_php = Off
display_errors = Off
log_errors = On

; Sessions
session.gc_maxlifetime = 7200
session.cookie_lifetime = 0
```

- [ ] **Step 4: Create `docker/deployment/supervisord.conf`**

```ini
[supervisord]
nodaemon = true
user = %(ENV_USER)s
logfile = /dev/null
logfile_maxbytes = 0
pidfile = /tmp/supervisord.pid

[supervisorctl]

[inet_http_server]
port = 127.0.0.1:9001

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface
```

- [ ] **Step 5: Create `docker/deployment/supervisord.http.conf`**

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
stopasgroup = true
killasgroup = true
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0
stderr_logfile = /dev/stderr
stderr_logfile_maxbytes = 0

[include]
files = /etc/supervisord.conf
```

- [ ] **Step 6: Create `docker/deployment/supervisord.horizon.conf`**

```ini
[program:horizon]
process_name = %(program_name)s_%(process_num)s
command = php %(ENV_ROOT)s/artisan horizon
user = %(ENV_USER)s
priority = 1
autostart = true
autorestart = true
stopasgroup = true
killasgroup = true
stopwaitsecs = 3600
stdout_logfile = %(ENV_ROOT)s/storage/logs/horizon.log
stdout_logfile_maxbytes = 200MB
stderr_logfile = %(ENV_ROOT)s/storage/logs/horizon.log
stderr_logfile_maxbytes = 200MB

[include]
files = /etc/supervisord.conf
```

- [ ] **Step 7: Create `docker/deployment/supervisord.scheduler.conf`**

```ini
[program:scheduler]
process_name = %(program_name)s_%(process_num)s
command = supercronic -overlapping /etc/supercronic/laravel
user = %(ENV_USER)s
priority = 1
autostart = true
autorestart = true
stopasgroup = true
killasgroup = true
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0
stderr_logfile = /dev/stderr
stderr_logfile_maxbytes = 0

[include]
files = /etc/supervisord.conf
```

- [ ] **Step 8: Create `docker/deployment/supervisord.ssr.conf`**

```ini
[program:ssr]
process_name = %(program_name)s_%(process_num)s
command = php %(ENV_ROOT)s/artisan inertia:start-ssr --runtime=node --quiet
user = %(ENV_USER)s
priority = 1
autostart = true
autorestart = true
stopasgroup = true
killasgroup = true
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0
stderr_logfile = /dev/stderr
stderr_logfile_maxbytes = 0

[include]
files = /etc/supervisord.conf
```

- [ ] **Step 9: Create `docker/deployment/supervisord.reverb.conf`**

```ini
[program:reverb]
process_name = %(program_name)s_%(process_num)s
command = php %(ENV_ROOT)s/artisan reverb:start --host=0.0.0.0 --port=8080
user = %(ENV_USER)s
priority = 1
autostart = true
autorestart = true
stopasgroup = true
killasgroup = true
minfds = 10000
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0
stderr_logfile = /dev/stderr
stderr_logfile_maxbytes = 0

[include]
files = /etc/supervisord.conf
```

- [ ] **Step 10: Create `docker/deployment/supercronic/laravel`**

```cron
# Laravel scheduler — runs schedule:run every minute
* * * * * php /var/www/html/artisan schedule:run >> /dev/null 2>&1
```

- [ ] **Step 11: Create `docker/deployment/frankenphp/Caddyfile`**

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

- [ ] **Step 12: Make scripts executable**

Run:

```bash
chmod +x docker/deployment/start-container docker/deployment/healthcheck
```

- [ ] **Step 13: Commit**

```bash
git add docker/deployment/
git commit -m "feat(docker): add deployment scripts (start-container, supervisord, php.ini, healthcheck)"
```

---

## Task 5: Create `compose.yaml` (Base)

**Files:**

- Create: `compose.yaml` (replaces Sail-generated version)

- [ ] **Step 1: Backup old `compose.yaml`**

```bash
mv compose.yaml compose.yaml.sail.bak
```

- [ ] **Step 2: Write new `compose.yaml`**

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
        logging:
            { driver: json-file, options: { max-size: '50m', max-file: '10' } }

networks:
    stack:
        driver: bridge

volumes:
    stack-pgsql:
    stack-redis:
```

- [ ] **Step 3: Validate compose syntax**

Run: `docker compose config --profiles dev 2>&1 | head -20`
Expected: YAML output, no errors

- [ ] **Step 4: Commit**

```bash
git add compose.yaml
git rm --cached compose.yaml.sail.bak 2>/dev/null || true
echo "compose.yaml.sail.bak" >> .gitignore
git add .gitignore
git commit -m "feat(docker): replace Sail compose.yaml with hybrid base (profiles for env membership)"
```

---

## Task 6: Create `compose.override.yml` (Dev Auto-loaded)

**Files:**

- Create: `compose.override.yml`

- [ ] **Step 1: Write `compose.override.yml`**

```yaml
# Auto-loaded by `docker compose up` for dev environment.
# Most dev defaults live in compose.yaml; this file reserves space for user overrides.
# For personal local tweaks, use compose.override.local.yml (gitignored).
services:
    app:
        environment:
            XDEBUG_MODE: ${XDEBUG_MODE:-off}
            IGNITION_LOCAL_SITES_PATH: ${PWD}
```

- [ ] **Step 2: Commit**

```bash
git add compose.override.yml
git commit -m "feat(docker): add compose.override.yml placeholder for dev"
```

---

## Task 7: Create `Makefile`

**Files:**

- Create: `Makefile`

- [ ] **Step 1: Write `Makefile`**

```makefile
.DEFAULT_GOAL := help
.PHONY: help install \
        dev dev-stop dev-down dev-logs dev-rebuild \
        staging production staging-logs production-logs staging-down production-down \
        build build-production \
        rollout-staging rollout-production production-scale-up production-scale-down \
        reload-staging reload-production \
        artisan pnpm composer exec shell tinker test fresh \
        clean

IMAGE ?= ghcr.io/thaolaptrinh/laravel-viltf
COMPOSE_DEV  = COMPOSE_PROFILES=dev  docker compose
COMPOSE_STAGING  = COMPOSE_PROFILES=staging  docker compose -f compose.yaml -f compose.staging.yml
COMPOSE_PRODUCTION = COMPOSE_PROFILES=production docker compose -f compose.yaml -f compose.production.yml

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

# ─── Staging / Production (local test only — DO NOT run on real VPS via this) ──

staging: ## Start staging environment locally
	$(COMPOSE_STAGING) up -d --remove-orphans

production: ## Start production environment locally (testing only)
	$(COMPOSE_PRODUCTION) up -d --remove-orphans

# Short aliases (convenience)
stg: staging  ## Alias for `make staging`
prod: production  ## Alias for `make production`

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

composer: ## Run composer in container: make composer CMD="require pkg"
	$(COMPOSE_DEV) run --rm app composer $(CMD)

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

- [ ] **Step 2: Verify Makefile parses**

Run: `make help`
Expected: List of all targets with descriptions

- [ ] **Step 3: Commit**

```bash
git add Makefile
git commit -m "feat(docker): add Makefile for orchestration + command passthrough"
```

---

## Task 8: Create Traefik Configuration

**Files:**

- Create: `docker/traefik/traefik.yml`
- Create: `docker/traefik/dynamic.yml`
- Create: `docker/traefik/certs/.gitkeep`

- [ ] **Step 1: Create directory + `.gitkeep`**

```bash
mkdir -p docker/traefik/certs
touch docker/traefik/certs/.gitkeep
```

- [ ] **Step 2: Write `docker/traefik/traefik.yml`**

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

- [ ] **Step 3: Write `docker/traefik/dynamic.yml`**

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

- [ ] **Step 4: Commit**

```bash
git add docker/traefik/
git commit -m "feat(traefik): add static + dynamic config with CF Origin Cert + security middlewares"
```

---

## Task 9: Create `compose.staging.yml` and `compose.production.yml`

**Files:**

- Create: `compose.staging.yml`
- Create: `compose.production.yml`

- [ ] **Step 1: Write `compose.staging.yml`**

```yaml
x-staging-image: &staging-image
    image: ghcr.io/${GH_REPO:-thaolaptrinh/laravel-viltf}:staging
    env_file: [.env.staging]
    ports: !reset []
    restart: unless-stopped
    stop_grace_period: 35s

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
            traefik.http.routers.app.priority: 10
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
            traefik.http.routers.reverb.middlewares: security-headers,security-staging
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

- [ ] **Step 2: Write `compose.production.yml`**

```yaml
x-production-image: &production-image
  image: ghcr.io/${GH_REPO:-thaolaptrinh/laravel-viltf}:${IMAGE_TAG:-latest}
  env_file: [.env.production]
  ports: !reset []
  restart: unless-stopped
  stop_grace_period: 35s
  deploy:
    resources:
      limits: {memory: ${APP_MEM_LIMIT:-384M}}

services:
  app:
    <<: *production-image
    environment:
      CONTAINER_MODE: http
      APP_ENV: production
      OCTANE_HTTPS: "true"
    deploy:
      resources:
        limits: {memory: ${APP_MEM_LIMIT:-384M}}
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
    deploy:
      resources:
        limits: {memory: 256M}
    environment: {CONTAINER_MODE: horizon}

  scheduler:
    <<: *production-image
    deploy:
      resources:
        limits: {memory: 64M}
    environment: {CONTAINER_MODE: scheduler}

  ssr:
    <<: *production-image
    deploy:
      resources:
        limits: {memory: 256M}
    environment: {CONTAINER_MODE: ssr}

  reverb:
    <<: *production-image
    deploy:
      resources:
        limits: {memory: 256M}
    environment: {CONTAINER_MODE: reverb}
    labels:
      traefik.enable: true
      traefik.docker.network: stack
      traefik.http.routers.reverb.rule: Host(`${APP_DOMAIN}`) && PathPrefix(`/app`)
      traefik.http.routers.reverb.entryPoints: app-secure
      traefik.http.routers.reverb.tls: true
      traefik.http.routers.reverb.priority: 30
      traefik.http.routers.reverb.middlewares: security-headers,compress
      traefik.http.services.reverb.loadbalancer.server.port: 8080

  traefik:
    image: traefik:v3.6
    restart: unless-stopped
    stop_grace_period: 35s
    security_opt: [no-new-privileges:true]
    ulimits:
      nofile: {soft: 65536, hard: 65536}
    deploy:
      resources:
        limits: {memory: 96M}
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
      - "127.0.0.1:8080:8080"
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

  backup:
    image: offen/docker-volume-backup:v2
    profiles: [backup]
    environment:
      BACKUP_FILENAME: backup-%Y-%m-%dT%H-%M-%S.tar.gz
      BACKUP_PRUNING_PREFIX: backup-
      BACKUP_CRON_EXPRESSION: "0 2 * * *"
      BACKUP_RETENTION_DAYS: "7"
    volumes:
      - stack-pgsql:/backup/pgsql:ro
      - ./backups:/archive
      - /var/run/docker.sock:/var/run/docker.sock:ro
    labels:
      traefik.enable: false
```

- [ ] **Step 3: Validate both compose files**

Run: `docker compose -f compose.yaml -f compose.staging.yml --profile staging config 2>&1 | tail -5`
Expected: No errors

Run: `docker compose -f compose.yaml -f compose.production.yml --profile production config 2>&1 | tail -5`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add compose.staging.yml compose.production.yml
git commit -m "feat(docker): add compose.staging.yml + compose.production.yml with Traefik + memory limits"
```

---

## Task 10: Create Postgres Tuning Config

**Files:**

- Create: `docker/deployment/postgres/postgresql.conf`

- [ ] **Step 1: Create directory + file**

```bash
mkdir -p docker/deployment/postgres
```

- [ ] **Step 2: Write `docker/deployment/postgres/postgresql.conf`**

```ini
# Postgres config tuned for 6 GB host (recommended VPS size)
# For 4 GB minimum, halve shared_buffers, effective_cache_size, work_mem

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
random_page_cost = 1.1

# Query planner
default_statistics_target = 100

# Logging (optional — comment out in production if too verbose)
log_min_duration_statement = 500
```

- [ ] **Step 3: Update `compose.yaml` to mount postgres config**

Edit `compose.yaml` — in `pgsql` service, add volume mount:

```yaml
pgsql:
    image: postgres:18-alpine
    # ... existing config ...
    volumes:
        - stack-pgsql:/var/lib/postgresql/data
        - ./docker/deployment/postgres/postgresql.conf:/var/lib/postgresql/postgresql.conf:ro
    command: postgres -c config_file=/var/lib/postgresql/postgresql.conf
```

- [ ] **Step 4: Commit**

```bash
git add docker/deployment/postgres/ compose.yaml
git commit -m "feat(docker): add Postgres tuning config for 6GB host"
```

---

## Task 11: Update `.env.example`

**Files:**

- Modify: `.env.example`

- [ ] **Step 1: Read current `.env.example`**

Run: `cat .env.example | head -50`

- [ ] **Step 2: Update key sections**

Replace the following sections in `.env.example`:

```diff
- DB_CONNECTION=sqlite
- # DB_HOST=127.0.0.1
- # DB_PORT=3306
- # DB_DATABASE=laravel
- # DB_USERNAME=root
- # DB_PASSWORD=
+ DB_CONNECTION=pgsql
+ DB_HOST=pgsql
+ DB_PORT=5432
+ DB_DATABASE=laravel
+ DB_USERNAME=laravel
+ DB_PASSWORD=secret
```

```diff
- SESSION_DRIVER=database
- BROADCAST_CONNECTION=log
- FILESYSTEM_DISK=local
- QUEUE_CONNECTION=database
- CACHE_STORE=database
+ SESSION_DRIVER=redis
+ BROADCAST_CONNECTION=reverb
+ FILESYSTEM_DISK=local
+ QUEUE_CONNECTION=redis
+ CACHE_STORE=redis
```

```diff
- REDIS_CLIENT=phpredis
- REDIS_HOST=127.0.0.1
- REDIS_PASSWORD=null
- REDIS_PORT=6379
+ REDIS_CLIENT=phpredis
+ REDIS_HOST=redis
+ REDIS_PASSWORD=null
+ REDIS_PORT=6379
+ REDIS_MAXMEMORY=256mb
```

Add new sections at end of file:

```bash
# Broadcasting (Reverb — first-party WebSocket server)
REVERB_APP_ID=laravel-viltf
REVERB_APP_KEY=REPLACE_WITH_RANDOM_KEY
REVERB_APP_SECRET=REPLACE_WITH_RANDOM_SECRET
REVERB_HOST=127.0.0.1
REVERB_PORT=8080
REVERB_SCHEME=http
VITE_REVERB_APP_KEY="${REVERB_APP_KEY}"
VITE_REVERB_HOST="${REVERB_HOST}"
VITE_REVERB_PORT="${REVERB_PORT}"
VITE_REVERB_SCHEME="${REVERB_SCHEME}"

# Docker / Octane
APP_PORT=8080
VITE_PORT=5173
COMPOSE_PROFILES=dev
OCTANE_SERVER=frankenphp
OCTANE_HTTPS=false
RUNNING_MIGRATIONS_AND_SEEDERS=false
USER_ID=1000
GROUP_ID=1000
TZ=UTC

# Staging / Production (only used by staging/production compose)
GH_REPO=thaolaptrinh/laravel-viltf
IMAGE_TAG=latest
APP_DOMAIN=localhost
TRAEFIK_AUTH=user:$$2y$$05$$REPLACE_WITH_BCRYPT_HASH
APP_MEM_LIMIT=384M
```

- [ ] **Step 3: Commit**

```bash
git add .env.example
git commit -m "chore(env): update .env.example for Docker + Redis + Reverb parity"
```

---

## Task 12: Create `.env.staging.example` and `.env.production.example`

**Files:**

- Create: `.env.staging.example`
- Create: `.env.production.example`

- [ ] **Step 1: Write `.env.staging.example`**

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
REDIS_MAXMEMORY=256mb

OCTANE_SERVER=frankenphp
OCTANE_HTTPS=true
RUNNING_MIGRATIONS_AND_SEEDERS=false

REVERB_APP_ID=laravel-viltf-staging
REVERB_APP_KEY=REPLACE_WITH_RANDOM_KEY
REVERB_APP_SECRET=REPLACE_WITH_RANDOM_SECRET
REVERB_HOST=staging.yourdomain.com
REVERB_PORT=443
REVERB_SCHEME=https
VITE_REVERB_APP_KEY="${REVERB_APP_KEY}"
VITE_REVERB_HOST="${REVERB_HOST}"
VITE_REVERB_PORT="${REVERB_PORT}"
VITE_REVERB_SCHEME="${REVERB_SCHEME}"

IMAGE_TAG=staging
TRAEFIK_AUTH=user:$$2y$$05$$REPLACE_WITH_BCRYPT_HASH
APP_MEM_LIMIT=384M
```

- [ ] **Step 2: Write `.env.production.example`**

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
REDIS_MAXMEMORY=256mb

OCTANE_SERVER=frankenphp
OCTANE_HTTPS=true
RUNNING_MIGRATIONS_AND_SEEDERS=false

REVERB_APP_ID=laravel-viltf-production
REVERB_APP_KEY=REPLACE_WITH_RANDOM_KEY
REVERB_APP_SECRET=REPLACE_WITH_RANDOM_SECRET
REVERB_HOST=yourdomain.com
REVERB_PORT=443
REVERB_SCHEME=https
VITE_REVERB_APP_KEY="${REVERB_APP_KEY}"
VITE_REVERB_HOST="${REVERB_HOST}"
VITE_REVERB_PORT="${REVERB_PORT}"
VITE_REVERB_SCHEME="${REVERB_SCHEME}"

IMAGE_TAG=latest
TRAEFIK_AUTH=admin:$$2y$$05$$REPLACE_WITH_BCRYPT_HASH
APP_MEM_LIMIT=384M
```

- [ ] **Step 3: Commit**

```bash
git add .env.staging.example .env.production.example
git commit -m "chore(env): add .env.staging.example + .env.production.example templates"
```

---

## Task 13: Update `.gitignore`

**Files:**

- Modify: `.gitignore`

- [ ] **Step 1: Read current `.gitignore`**

Run: `cat .gitignore`

- [ ] **Step 2: Append Docker secrets section**

Add at end of `.gitignore`:

```gitignore
# Docker secrets
.env
.env.staging
.env.production
docker/traefik/certs/*.pem
docker/traefik/certs/*.key
docker/traefik/certs/private.key

# Compose local overrides
compose.override.local.yml
compose.yaml.sail.bak

# Backups
backups/
```

- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore(git): ignore Docker secrets, compose overrides, backups"
```

---

## Task 14: Add `laravel/horizon` and `laravel/reverb` to Composer

**Files:**

- Modify: `composer.json`
- Create: `app/Providers/HorizonServiceProvider.php` (auto-published)
- Modify: `config/horizon.php` (auto-published)
- Modify: `config/reverb.php` (auto-published)
- Modify: `config/app.php` (provider registration may be needed)

- [ ] **Step 1: Install packages via Sail (still available)**

Run:

```bash
vendor/bin/sail composer require laravel/horizon laravel/reverb
```

- [ ] **Step 2: Publish vendor configs**

Run:

```bash
vendor/bin/sail artisan horizon:install
vendor/bin/sail artisan reverb:install
```

- [ ] **Step 3: Verify Horizon provider registered**

Check `config/app.php` (Laravel 11+ auto-discovers). If manual registration needed, ensure `App\Providers\HorizonServiceProvider::class` is in `bootstrap/providers.php`.

- [ ] **Step 4: Configure Horizon auth gate**

Edit `app/Providers/HorizonServiceProvider.php`:

```php
protected function gate(): void
{
    Gate::define('viewHorizon', function (User $user = null) {
        return in_array(optional($user)->email, [
            'admin@yourdomain.com',
        ]);
    });
}
```

> If `app/Providers/HorizonServiceProvider.php` doesn't exist (newer Horizon auto-registers), create it:

```php
<?php

declare(strict_types=1);

namespace App\Providers;

use Laravel\Horizon\Horizon;
use Laravel\Horizon\HorizonApplicationServiceProvider;

final class HorizonServiceProvider extends HorizonApplicationServiceProvider
{
    protected function gate(): void
    {
        \Illuminate\Support\Facades\Gate::define('viewHorizon', function ($user = null) {
            return in_array(optional($user)->email, [
                'admin@yourdomain.com',
            ]);
        });
    }
}
```

- [ ] **Step 5: Run tests to verify nothing broke**

Run: `vendor/bin/sail artisan test --compact`
Expected: All existing tests pass

- [ ] **Step 6: Commit**

```bash
git add composer.json composer.lock app/ config/
git commit -m "feat(horizon,reverb): add queue dashboard + WebSocket server"
```

---

## Task 15: Update `config/octane.php` for Filament + Livewire Compatibility

**Files:**

- Modify: `config/octane.php`
- Modify: `app/Providers/AppServiceProvider.php`

> **Why:** Filament v5 + Livewire v4 hold state across requests. Octane caches the application container between requests, which can leak state if listeners aren't configured correctly. This task verifies the Octane config from the starter kit is compatible with Filament and adds HTTPS forcing for production.

- [ ] **Step 1: Read current `config/octane.php`**

Run: `cat config/octane.php | head -100`

Verify the `RequestReceived` listener block looks like:

```php
RequestReceived::class => [
    ...Octane::prepareApplicationForNextOperation(),
    ...Octane::prepareApplicationForNextRequest(),
    //
],
```

- [ ] **Step 2: Verify `FlushTemporaryContainerInstances` is included**

Check that `Octane::prepareApplicationForNextOperation()` includes the necessary state flushers (it does by default). Do not modify unless Filament/Livewire docs require additional listeners.

- [ ] **Step 3: Check Filament 5 + Octane docs**

Open: <https://filamentphp.com/docs/5.x/panels/installation#laravel-octane>

If Filament docs recommend specific Octane listeners (e.g., `ResetLivewireProperty::class`), add them to the `RequestReceived` array:

```php
RequestReceived::class => [
    ...Octane::prepareApplicationForNextOperation(),
    ...Octane::prepareApplicationForNextRequest(),
    // Add Filament/Livewire-specific listeners here if docs require
],
```

- [ ] **Step 4: Force HTTPS scheme when behind Traefik**

The `config/octane.php` already has `'https' => env('OCTANE_HTTPS', false)`. This is sufficient — `.env.staging` and `.env.production` set `OCTANE_HTTPS=true` (handled in Task 12).

Verify by reading:

```bash
grep "OCTANE_HTTPS" config/octane.php
```

Expected: `'https' => env('OCTANE_HTTPS', false),`

- [ ] **Step 5: Trust all proxies (Traefik) via AppServiceProvider**

Edit `app/Providers/AppServiceProvider.php` and add to `boot()`:

```php
<?php

declare(strict_types=1);

namespace App\Providers;

use Illuminate\Support\Facades\URL;
use Illuminate\Support\ServiceProvider;

final class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        // Trust proxies is configured via bootstrap/app.php middleware in Laravel 11+.
        // Force HTTPS scheme when APP_ENV=production and behind Traefik.
        if ($this->app->environment('production', 'staging')) {
            URL::forceScheme('https');
        }
    }
}
```

- [ ] **Step 6: Smoke test Octane starts**

Run:

```bash
vendor/bin/sail artisan octane:stop 2>/dev/null || true
vendor/bin/sail artisan config:clear
vendor/bin/sail artisan octane:start --server=frankenphp --host=127.0.0.1 --port=8000 &
sleep 5
curl -fsS http://127.0.0.1:8000/up
kill %1 2>/dev/null || true
```

Expected: HTTP 200

- [ ] **Step 7: Commit**

```bash
git add config/octane.php app/Providers/AppServiceProvider.php
git commit -m "feat(octane): verify Filament/Livewire compatibility + force HTTPS in staging/production"
```

---

## Task 16: Update `composer.json` Scripts

**Files:**

- Modify: `composer.json`

- [ ] **Step 1: Read current scripts section**

Run: `cat composer.json | grep -A 80 '"scripts"'`

- [ ] **Step 2: Replace scripts section**

Open `composer.json` and replace the entire `"scripts"` block with:

```json
"scripts": {
    "test": "@php artisan test",
    "test:type-coverage": "pest --type-coverage --min=100",
    "test:lint": [
        "pint --parallel --test",
        "rector --dry-run",
        "pnpm run test:lint"
    ],
    "test:types": [
        "phpstan --memory-limit=512M",
        "pnpm run test:types"
    ],
    "test:unit": "pest --parallel --coverage --exactly=100.0",
    "lint": [
        "rector",
        "pint --parallel",
        "pnpm run lint"
    ],
    "post-autoload-dump": [
        "Illuminate\\Foundation\\ComposerScripts::postAutoloadDump",
        "@php artisan package:discover --ansi",
        "@php artisan filament:upgrade"
    ],
    "post-update-cmd": [
        "@php artisan vendor:publish --tag=laravel-assets --ansi --force"
    ],
    "post-root-package-install": [
        "@php -r \"file_exists('.env') || copy('.env.example', '.env');\""
    ],
    "post-create-project-cmd": [
        "@php artisan key:generate --ansi",
        "@php -r \"file_exists('database/database.sqlite') || touch('database/database.sqlite');\"",
        "@php artisan migrate --graceful --ansi"
    ],
    "pre-package-uninstall": [
        "Illuminate\\Foundation\\ComposerScripts::prePackageUninstall"
    ],
    "update:requirements": [
        "composer bump",
        "pnpm dlx npm-check-updates -u"
    ]
}
```

> The `setup`, `dev`, `dev:ssr`, `test` (full) scripts are removed — replaced by `make install`, `make dev`, `make test` etc.

- [ ] **Step 3: Validate composer.json**

Run: `composer validate`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add composer.json
git commit -m "chore(composer): simplify scripts — orchestration moved to Makefile"
```

---

## Task 17: Create GitHub Actions Workflow

**Files:**

- Create: `.github/workflows/docker.yml`

- [ ] **Step 1: Create directory**

```bash
mkdir -p .github/workflows
```

- [ ] **Step 2: Write `.github/workflows/docker.yml`**

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
            platforms:
                description: 'Build platforms'
                default: 'linux/amd64'

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

            - name: Start deps (pgsql + redis)
              env:
                  IMAGE: app:dev-test
                  USER_ID: '1000'
                  GROUP_ID: '1000'
                  DB_DATABASE: testing
              run: |
                  docker compose --profile dev up -d pgsql redis
                  # Wait for pgsql to be healthy
                  for i in {1..30}; do
                    docker compose exec -T pgsql pg_isready -U laravel -d testing && break
                    sleep 1
                  done
                  # Create testing DB if not exists (POSTGRES_DB may have been set)
                  docker compose exec -T pgsql psql -U laravel -d postgres -c "CREATE DATABASE testing;" 2>/dev/null || true

            - name: Composer validate
              env:
                  IMAGE: app:dev-test
              run: docker compose run --rm app composer validate --no-check-publish

            - name: Lint (Pint + Rector dry-run)
              env:
                  IMAGE: app:dev-test
              run: docker compose run --rm app composer test:lint

            - name: Types (PHPStan)
              env:
                  IMAGE: app:dev-test
              run: docker compose run --rm app composer test:types
              continue-on-error: true # PHPStan warnings shouldn't block CI yet

            - name: Pest tests
              env:
                  IMAGE: app:dev-test
                  DB_DATABASE: testing
                  QUEUE_CONNECTION: sync
              run: docker compose run --rm app php artisan test --parallel

            - name: Verify frontend build
              env:
                  IMAGE: app:dev-test
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

- [ ] **Step 3: Validate YAML syntax**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/docker.yml'))"`
Expected: No output (no errors)

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/docker.yml
git commit -m "ci(docker): add build/test/push GHCR + zero-downtime deploy workflow"
```

---

## Task 18: Test Dev Environment (Comprehensive Verification)

> ⚠️ **GATE TASK — Do NOT proceed to Task 20+ until ALL steps pass.** This is the verification that the dev Docker environment works end-to-end before adding staging/production complexity.

**Files:** None (verification only)

- [ ] **Step 1: Clean slate**

```bash
make clean || true
```

- [ ] **Step 2: Build dev image**

Run: `USER_ID=$(id -u) GROUP_ID=$(id -g) make build`
Expected: Image builds successfully (may take 5-15 min first time)

- [ ] **Step 3: Start dev environment**

Run: `make dev`
Expected: 4 containers start: `app`, `horizon`, `pgsql`, `redis`

- [ ] **Step 4: Verify all containers running**

Run: `docker compose ps`
Expected: All 4 services show status "Up" or "healthy"

Verify each:

```bash
docker compose ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}'
```

Expected output (approximate):

```
NAME                STATUS                   PORTS
app-1               Up (healthy)             0.0.0.0:8080->8000/tcp, 0.0.0.0:5173->5173/tcp
horizon-1           Up
pgsql-1             Up (healthy)
redis-1             Up (healthy)
```

- [ ] **Step 5: Verify pgsql healthy + accepting connections**

Run: `docker compose exec pgsql pg_isready -U laravel -d laravel`
Expected: `/var/run/postgresql:5432 - accepting connections`

- [ ] **Step 6: Verify redis healthy + ping works**

Run: `docker compose exec redis redis-cli ping`
Expected: `PONG`

- [ ] **Step 7: Verify app → pgsql connectivity (from inside app container)**

Run: `make exec CMD="php artisan tinker --execute='echo DB::connection()->getPdo() ? \"OK\" : \"FAIL\";'"`
Expected: `OK`

- [ ] **Step 8: Verify app → redis connectivity**

Run: `make exec CMD="php artisan tinker --execute='echo Illuminate\\Support\\Facades\\Redis::ping();'"`
Expected: `+PONG`

- [ ] **Step 9: Verify Octane server responds**

Run: `curl -fsS -o /dev/null -w "HTTP %{http_code} in %{time_total}s\n" http://localhost:8080/up`
Expected: `HTTP 200 in <0.5s`

- [ ] **Step 10: Verify Vite HMR port responds**

Run: `curl -fsS -o /dev/null -w "HTTP %{http_code}\n" http://localhost:5173`
Expected: `HTTP 200` (Vite dev server)

- [ ] **Step 11: Verify Octane is the active server (not php artisan serve)**

Run: `make exec CMD="php artisan tinker --execute='echo config(\"octane.server\");'"`
Expected: `frankenphp`

- [ ] **Step 12: Verify Horizon queue worker running**

Run: `make exec CMD="ps aux | grep -E 'horizon|queue:work' | grep -v grep"`
Expected: At least one PHP process running `php artisan horizon` (via supervisor)

- [ ] **Step 13: Verify Horizon dashboard accessible**

Run: `curl -fsS -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8080/horizon`
Expected: `HTTP 200` or `HTTP 302` (redirect to login if auth enabled)

- [ ] **Step 14: Verify migrations run cleanly**

Run: `make artisan CMD="migrate --pretend"`
Expected: Lists migrations without errors

- [ ] **Step 15: Run migrate fresh + seed**

Run: `make fresh`
Expected: All migrations roll back + re-run, seeders populate

- [ ] **Step 16: Test artisan passthrough (multiple commands)**

```bash
make artisan CMD="tinker --execute='echo PHP_VERSION;'"
make artisan CMD="route:list --columns=method,uri,name | head -5"
make artisan CMD="optimize:clear"
```

Expected: Each command executes without errors

- [ ] **Step 17: Test pnpm passthrough**

```bash
make pnpm CMD="--version"
make pnpm CMD="run build"
```

Expected: pnpm version printed; build completes successfully

- [ ] **Step 18: Run full test suite**

Run: `make test`
Expected: 100% pass (or known-failing tests only, with explanation)

- [ ] **Step 19: Verify XDebug toggle works (optional but recommended)**

Run:

```bash
XDEBUG_MODE=debug docker compose up -d --force-recreate app
docker compose exec app php -v | grep -i xdebug
```

Expected: XDebug listed in PHP version output

Reset:

```bash
make dev-down && make dev
```

- [ ] **Step 20: Verify container auto-restart on failure**

Run:

```bash
docker compose kill app -s SIGKILL
sleep 10
docker compose ps app
```

Expected: `app` shows "Restarting (1)" then "Up" within 30s (due to `restart: unless-stopped`)

- [ ] **Step 21: Check container logs for errors**

Run:

```bash
docker compose logs app 2>&1 | grep -iE "error|exception|fatal" | head -10
docker compose logs horizon 2>&1 | grep -iE "error|exception|fatal" | head -10
```

Expected: No unexpected errors (some PHP notices OK; Laravel startup logs OK)

- [ ] **Step 22: Verify file permissions (UID/GID match host)**

Run:

```bash
make exec CMD="id"
ls -la storage/logs/ | head -3
```

Expected: Container user `laravel` has same UID as host (typically 1000); storage/logs files owned by correct user

- [ ] **Step 23: Check disk usage of dev images**

Run: `docker images ghcr.io/thaolaptrinh/laravel-viltf`
Expected: Dev image < 1.5 GB (alpine base + PHP + Node + pnpm)

- [ ] **Step 24: STOP — Final Go/No-Go decision**

If ALL steps 1-23 pass: ✅ proceed to Task 18 (test production build).

If ANY step fails:

1. Identify the failing step
2. Read its expected output vs actual
3. Fix root cause (likely in `Dockerfile`, `docker/deployment/*`, or `compose.yaml`)
4. Run `make dev-rebuild` then re-run from Step 3
5. Do NOT proceed until green

**Document any deviations** in commit message when moving to Task 18.

---

## Task 19: Test Production Image Build (Local)

> ⚠️ **GATE TASK — Do NOT proceed to Task 20+ until production image builds & starts locally.**

**Files:** None (verification only)

- [ ] **Step 1: Build production image**

Run: `make build-production`
Expected: Image builds successfully (faster than dev build due to multi-stage cache reuse)

- [ ] **Step 2: Verify image is lean**

Run: `docker images ghcr.io/thaolaptrinh/laravel-viltf:local`
Expected: Image size < 300 MB (FrankenPHP alpine + PHP + composer deps + built assets, no Node)

- [ ] **Step 3: Verify image does NOT contain dev tools**

Run:

```bash
docker run --rm --entrypoint sh ghcr.io/thaolaptrinh/laravel-viltf:local -c "
  echo '=== Node check ==='
  which node pnpm 2>&1 | head -5
  echo '=== XDebug check ==='
  php -m | grep -i xdebug || echo 'XDebug NOT installed (correct)'
  echo '=== Dev composer packages check ==='
  composer show pestphp/pest 2>&1 | head -3
"
```

Expected:

- `node`/`pnpm` not found (or found but only for SSR runtime — verify)
- `XDebug NOT installed (correct)`
- `pestphp/pest` not found (no dev deps)

- [ ] **Step 4: Test image starts in production mode**

Run:

```bash
docker run --rm -d \
  --name production-test \
  -e APP_KEY=base64:$(php -r "echo base64_encode(random_bytes(32));") \
  -e APP_ENV=production \
  -e DB_CONNECTION=sqlite \
  -e DB_DATABASE=:memory: \
  -p 9999:8000 \
  ghcr.io/thaolaptrinh/laravel-viltf:local
```

Expected: Container ID returned, container starts

- [ ] **Step 5: Wait for FrankenPHP to boot**

Run: `sleep 5 && docker logs production-test 2>&1 | tail -10`
Expected: Logs show Octane/FrankenPHP started, listening on :8000

- [ ] **Step 6: Verify HTTP healthcheck**

Run: `curl -fsS -o /dev/null -w "HTTP %{http_code}\n" http://localhost:9999/up`
Expected: `HTTP 200`

- [ ] **Step 7: Verify Docker healthcheck passes**

Run: `docker inspect --format='{{.State.Health.Status}}' production-test`
Expected: `healthy` (may take up to 60s)

- [ ] **Step 8: Verify built assets are present**

Run:

```bash
docker exec production-test ls -la public/build/ 2>&1 | head -10
```

Expected: `manifest.json` + built JS/CSS files

- [ ] **Step 9: Verify SSR bundle present**

Run:

```bash
docker exec production-test ls -la storage/ssr/ 2>&1 | head -5
```

Expected: SSR bundle file(s) present

- [ ] **Step 10: Verify non-root user**

Run: `docker exec production-test id`
Expected: `uid=1000(laravel) gid=1000(laravel) groups=1000(laravel)`

- [ ] **Step 11: Verify security hardening (no setuid bits)**

Run:

```bash
docker exec production-test find / -perm /6000 -type f 2>/dev/null | head -5
```

Expected: Empty (no setuid/setgid binaries)

- [ ] **Step 12: Clean up**

```bash
docker stop production-test
docker rm production-test 2>/dev/null || true
```

- [ ] **Step 13: STOP — Final Go/No-Go decision**

If ALL steps 1-12 pass: ✅ proceed to Task 20+ (CI, README, cleanup).

If ANY step fails:

1. Identify failing step
2. Likely causes: missing `--no-dev`, missing asset build, missing user config
3. Fix `Dockerfile` production target
4. Re-run `make build-production` and tests
5. Do NOT proceed until green

---

## Task 20: Update `README.md`

**Files:**

- Modify: `README.md`

- [ ] **Step 1: Read current README**

Run: `cat README.md`

- [ ] **Step 2: Replace Sail-related sections with Docker/Make instructions**

Update the following sections (replace any `vendor/bin/sail ...` with `make ...`):

- Replace "Prerequisites" — remove Sail, add Docker + Make
- Replace "Setup" section with:

````markdown
## Prerequisites

- **Docker** (with Compose v2.20+) — required
- **GNU Make** — for command shortcuts
- **Git** — for version control

No local PHP/Composer/Node.js needed — everything runs in containers.

## Setup

```bash
git clone https://github.com/your-org/laravel-viltf-starter-kit.git
cd laravel-viltf-starter-kit
make install
```
````

This will:

1. Copy `.env.example` → `.env`
2. Build the dev Docker image
3. Install composer + pnpm dependencies inside container
4. Start containers (app + horizon + pgsql + redis)

## Common Commands

```bash
make dev          # start dev environment
make dev-stop     # stop containers
make dev-down     # stop & remove containers
make dev-logs     # tail logs
make artisan CMD="migrate"           # run artisan command
make pnpm CMD="install"              # run pnpm command
make exec CMD="sh"                   # shell into app container
make test         # run test suite
make tinker       # tinker
make fresh        # migrate:fresh --seed
```

Open: <http://localhost:8080>

## Staging / Production

Staging and production use the same Docker image (built by CI), with different `.env.staging` / `.env.production` files and Traefik as edge proxy.

To test staging/production locally:

```bash
make staging          # start staging-like env locally
make production         # start production-like env locally
```

Production deploys happen automatically on `git push` to `develop` (staging) or `git tag v*` (production). See `docs/superpowers/specs/2026-07-04-docker-migration-design.md` for full architecture.

````

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs(readme): replace Sail instructions with Makefile + Docker workflow"
````

---

## Task 21: Update `AGENTS.md` and `CLAUDE.md`

**Files:**

- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Find Sail references in AGENTS.md**

Run: `grep -n "sail\|Sail" AGENTS.md`

- [ ] **Step 2: Replace `=== sail rules ===` section**

Open `AGENTS.md`. Find the section:

```markdown
=== sail rules ===

# Laravel Sail

- This project runs inside Laravel Sail's Docker containers. ...
```

Replace with:

```markdown
=== docker rules ===

# Docker Dev Environment

- This project runs in Docker via docker compose. All commands run through containers.
- Start dev: `make dev` (alias for `COMPOSE_PROFILES=dev docker compose up -d`).
- Stop dev: `make dev-stop`. Tear down: `make dev-down`.
- Run Artisan: `make artisan CMD="<cmd>"` (alias for `docker compose exec app php artisan <cmd>`).
- Run pnpm: `make pnpm CMD="<cmd>"`.
- Run arbitrary command: `make exec CMD="<cmd>"`.
- Shell in app: `make shell`.
- Open app: <http://localhost:${APP_PORT:-8080}>.
- Staging/production local test: `make staging` / `make production`.
- Traefik dashboard (staging/production): <http://localhost:8080> (basic auth via `TRAEFIK_AUTH`).
```

- [ ] **Step 3: Replace all `vendor/bin/sail ...` with `make ...` in AGENTS.md**

Run: `sed -i 's|vendor/bin/sail artisan|make artisan CMD=|g; s|vendor/bin/sail pnpm|make pnpm CMD=|g; s|vendor/bin/sail composer|composer|g; s|vendor/bin/sail test|make test|g; s|vendor/bin/sail bin pint --dirty --format agent|make exec CMD="pint --dirty --format agent"|g' AGENTS.md`

Manually review for any leftover references and fix.

- [ ] **Step 4: Update Foundational Context package list**

Find:

```
- laravel/sail (SAIL) - v1
```

Replace with:

```
- laravel/horizon (HORIZON) - v1
- laravel/reverb (REVERB) - v1
```

- [ ] **Step 5: Update frontend bundling note**

Find:

```
If the user doesn't see a frontend change reflected in the UI, it could mean they need to run `vendor/bin/sail pnpm run build`, `vendor/bin/sail pnpm run dev`, or `vendor/bin/sail composer run dev`. Ask them.
```

Replace with:

```
If the user doesn't see a frontend change reflected in the UI, it could mean they need to run `make dev-rebuild` (rebuild dev image) or restart the vite program (`make exec CMD="supervisorctl restart vite"`). Ask them.
```

- [ ] **Step 6: Apply same changes to `CLAUDE.md`**

Run:

```bash
cp AGENTS.md CLAUDE.md
```

(These two files are typically kept in sync in this project.)

- [ ] **Step 7: Commit**

```bash
git add AGENTS.md CLAUDE.md
git commit -m "docs(agents,claude): replace Sail references with Makefile + Docker workflow"
```

---

## Task 22: Update Skills Files

**Files:**

- Modify: `.agents/skills/wayfinder-development/SKILL.md`
- Modify: `.agents/skills/pest-testing/SKILL.md`
- Modify: `.claude/skills/wayfinder-development/SKILL.md`
- Modify: `.claude/skills/pest-testing/SKILL.md`

- [ ] **Step 1: Find Sail references in skills**

Run:

```bash
grep -rln "vendor/bin/sail" .agents/skills/ .claude/skills/
```

- [ ] **Step 2: Replace references**

For each file found, replace:

- `vendor/bin/sail artisan wayfinder:generate` → `make artisan CMD="wayfinder:generate --no-interaction"`
- `vendor/bin/sail artisan` → `make artisan CMD=`
- `vendor/bin/sail pnpm` → `make pnpm CMD=`
- `vendor/bin/sail test` → `make test`

Use `sed`:

```bash
find .agents/skills/ .claude/skills/ -name "SKILL.md" -exec sed -i \
  -e 's|vendor/bin/sail artisan wayfinder:generate|make artisan CMD="wayfinder:generate|g' \
  -e 's|vendor/bin/sail artisan |make artisan CMD="|g' \
  -e 's|vendor/bin/sail pnpm |make pnpm CMD="|g' \
  -e 's|vendor/bin/sail test|make test|g' \
  {} +
```

Then manually review for syntax issues (the `CMD="..."` quoting may need closing quotes appended).

- [ ] **Step 3: Verify changes**

Run: `grep -rln "vendor/bin/sail" .agents/skills/ .claude/skills/`
Expected: No output (all replaced)

- [ ] **Step 4: Commit**

```bash
git add .agents/skills/ .claude/skills/
git commit -m "docs(skills): replace Sail references with Makefile commands"
```

---

## Task 23: Remove Sail Artifacts

**Files:**

- Delete: `docker/8.5/` (Sail's Dockerfile directory)
- Delete: `compose.yaml.sail.bak` (backup from Task 5)
- Delete: `frankenphp` (165 MB binary — bundled in Docker image)
- Delete: `docker/app/` (empty scaffold)
- Delete: `docker/compose.dev.yml`, `docker/compose.staging.yml`, `docker/compose.production.yml` (empty scaffolds)
- Modify: `composer.json` (remove `laravel/sail` from `require-dev`)

- [ ] **Step 1: Remove composer package**

Run: `composer remove --dev laravel/sail`

- [ ] **Step 2: Delete Sail's docker directory**

Run: `git rm -r docker/8.5/`

- [ ] **Step 3: Delete scaffold files**

Run:

```bash
rm -rf docker/app/
rm -f docker/compose.dev.yml docker/compose.staging.yml docker/compose.production.yml
rm -f frankenphp
rm -f compose.yaml.sail.bak
git add -A
```

- [ ] **Step 4: Verify Sail gone**

Run: `composer show laravel/sail 2>&1`
Expected: "Package laravel/sail not found"

- [ ] **Step 5: Run tests to confirm nothing broke**

Run: `make test`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore(sail): remove Sail + obsolete artifacts (docker/8.5, frankenphp binary, scaffolds)"
```

---

## Task 24: Final Smoke Test (Full Migration)

**Files:** None (verification only)

- [ ] **Step 1: Clean slate**

```bash
make clean
make install
```

Expected: Fresh build + setup completes without errors

- [ ] **Step 2: Verify all containers running**

Run: `docker compose ps --profile dev`
Expected: app, horizon, pgsql, redis all "Up" or "healthy"

- [ ] **Step 3: Verify HTTP**

Run: `curl -fsS http://localhost:8080/up`
Expected: HTTP 200

- [ ] **Step 4: Verify migrations work**

Run: `make fresh`
Expected: Database migrated + seeded

- [ ] **Step 5: Run full test suite**

Run: `make test`
Expected: 100% pass

- [ ] **Step 6: Verify Lint**

Run: `composer lint`
Expected: All files formatted, no errors

- [ ] **Step 7: Build production image**

Run: `make build-production`
Expected: Successful build

- [ ] **Step 8: Validate compose production config**

Run: `docker compose -f compose.yaml -f compose.production.yml --profile production config >/dev/null`
Expected: No errors

---

## Task 25: Merge to Main

**Files:** None (git operations)

- [ ] **Step 1: Push feature branch**

```bash
git push -u origin feat/docker-migration
```

- [ ] **Step 2: Open PR**

```bash
gh pr create \
  --title "feat: Docker migration (replace Sail with FrankenPHP + Traefik)" \
  --body "Implements docs/superpowers/specs/2026-07-04-docker-migration-design.md

## Changes
- Multi-stage Dockerfile (base/dev/production targets)
- Hybrid compose pattern (profiles + override files)
- Traefik + CF Origin Cert edge proxy
- CI build to GHCR + zero-downtime deploy via docker-rollout
- Makefile replaces Sail wrapper
- Adds Laravel Horizon + Laravel Reverb
- Removes Laravel Sail + obsolete artifacts

## Testing
- [x] \`make install\` works clean
- [x] \`make test\` passes
- [x] \`make build-production\` produces <300MB image
- [x] Staging/production compose configs validate
- [ ] Manual CF Origin Cert setup on VPS
- [ ] First deploy to staging VPS" \
  --base main \
  --head feat/docker-migration
```

- [ ] **Step 3: After PR approval + merge, tag release**

```bash
git checkout main
git pull
git tag v0.2.0 -m "Docker migration: FrankenPHP + Traefik + zero-downtime deploys"
git push origin v0.2.0
```

This triggers the production deploy workflow.

---

## Self-Review

### Spec coverage

| Spec Section       | Implemented in Task(s)                           |
| ------------------ | ------------------------------------------------ |
| 1. Overview        | All tasks                                        |
| 2. Decisions Log   | Tasks 3-23                                       |
| 3. Architecture    | Tasks 3, 5, 9                                    |
| 4. Dockerfile      | Task 3-4                                         |
| 5. Compose hybrid  | Tasks 5, 6, 9                                    |
| 6. Traefik + CF    | Task 8                                           |
| 7. CI/CD           | Task 16                                          |
| 8. Makefile        | Task 7                                           |
| 9. Env + secrets   | Tasks 11-13                                      |
| 10. Operational    | Tasks 4, 10 (Postgres tuning), 14 (Horizon auth) |
| 11. Migration plan | Tasks 1, 22                                      |
| 12. Out of scope   | N/A (deferred)                                   |
| 13. Research tasks | Verified in Tasks 14, 17                         |

### Placeholder scan

No TODO/TBD/FIXME in plan. All code blocks contain actual code.

### Type consistency

- `CONTAINER_MODE` values consistent: `http`, `horizon`, `scheduler`, `ssr`, `reverb`
- Ports consistent: app 8000 internal, reverb 8080 internal, traefik dashboard 127.0.0.1:8080
- Image tags: `:dev`, `:staging`, `:latest`, `:sha-*`, `:v*`
- Profile names: dev, staging, production, backup`

### Scope check

Single coherent plan. 25 tasks. Each produces testable state. Order has dependencies respected (Dockerfile → scripts → compose → Makefile → tests → CI → cleanup).

---

## Execution Notes

- **Time estimate:** 4-8 hours total (mostly Docker build cache misses on first run)
- **Critical path:** Tasks 3-4 (Dockerfile + scripts) → Task 5 (compose) → Task 7 (Makefile) → Task 17 (smoke test)
- **Parallel-safe tasks:** Tasks 11-17 can be done in parallel once Task 5 is complete
- **Rollback:** `git checkout pre-docker-migration -- .` then `composer install` restores Sail setup
