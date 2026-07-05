# syntax=docker/dockerfile:1.7

ARG PHP_VERSION=8.5
ARG FRANKENPHP_VERSION=1.12.4
ARG COMPOSER_VERSION=2.8
ARG NODE_VERSION=22

# ─── Composer binary (alias used by base stage to copy composer binary) ─────
FROM composer:${COMPOSER_VERSION} AS composer-binary

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
    libsodium-dev libpng-dev libzip-dev icu-libs postgresql-libs && \
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
COPY --link --from=composer-binary /usr/bin/composer /usr/bin/composer

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
# Extends `base` (PHP 8.5 + extensions) to ensure platform check matches runtime.
# Note: autoload IS generated here because dev target mounts source at runtime
# (no composer.json available at build time for dump-autoload).
FROM base AS composer-dev
WORKDIR /app
COPY --link composer.json composer.lock ./
RUN composer install --no-interaction --no-scripts --no-progress

# ─── Composer deps (production) ─────────────────────────────────────────────
FROM base AS composer-production
WORKDIR /app
COPY --link composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --no-autoloader --no-scripts --no-progress --optimize --apcu

# ─── Assets stage ───────────────────────────────────────────────────────────
FROM node:${NODE_VERSION}-alpine AS assets
WORKDIR /app
COPY --link package.json pnpm-lock.yaml ./
RUN corepack enable pnpm && corepack prepare pnpm@latest --activate && \
    pnpm install --frozen-lockfile
COPY --link . .
RUN pnpm run build && pnpm run build:ssr

# ─── Node runtime (alias used by dev stage to copy node binary) ─────────────
FROM node:${NODE_VERSION}-alpine AS node-runtime

# ─── Dev target ─────────────────────────────────────────────────────────────
FROM base AS dev

# XDebug + Node + pnpm for dev workflow
RUN apk add --no-cache \
    linux-headers autoconf make g++ && \
    pecl install xdebug && \
    docker-php-ext-enable xdebug && \
    apk del linux-headers autoconf make g++ && \
    rm -rf /var/cache/apk/*

# Install Node + pnpm in dev target (for Vite HMR) — copy from node-runtime stage
COPY --link --from=node-runtime /usr/local/bin /usr/local/bin
COPY --link --from=node-runtime /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN corepack enable pnpm && corepack prepare pnpm@latest --activate

# Dev vendor (with autoload generated, no source code needed)
COPY --link --chown=${USER}:${GROUP} --from=composer-dev /app/vendor ./vendor

ENV WITH_VITE=true \
    XDEBUG_MODE=off

USER ${USER}
EXPOSE 8000 5173 9003
ENTRYPOINT ["start-container"]
CMD []

# ─── Production target ──────────────────────────────────────────────────────
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
