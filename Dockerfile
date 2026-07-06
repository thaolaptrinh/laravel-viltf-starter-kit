# syntax=docker/dockerfile:1.7

ARG PHP_VERSION=8.5
ARG FRANKENPHP_VERSION=1.12.4
ARG COMPOSER_VERSION=2.8
ARG NODE_VERSION=22

# ─── Composer binary ─────────────────────────────────────────────────────────
FROM composer:${COMPOSER_VERSION} AS composer-binary

# ─── Base stage ──────────────────────────────────────────────────────────────
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
    XDG_CONFIG_HOME=${ROOT}/.config \
    XDG_DATA_HOME=${ROOT}/.data

WORKDIR ${ROOT}

SHELL ["/bin/sh", "-eou", "pipefail", "-c"]

RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone

# System packages — tini as PID 1 (reap zombies + forward signals)
RUN apk add --no-cache \
    curl wget vim tzdata ncdu procps unzip ca-certificates bash tini \
    libsodium-dev libpng-dev libzip-dev icu-libs postgresql-libs && \
    rm -rf /var/cache/apk/*

# PHP extensions
RUN install-php-extensions \
    apcu pcntl mbstring bcmath sockets pdo_pgsql \
    opcache exif zip intl gd redis ffi uv

# Supercronic (scheduler)
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
RUN (getent group ${GROUP} || addgroup -g ${GROUP_ID} ${GROUP}) && \
    (getent passwd ${USER} || adduser -D -G ${GROUP} -u ${USER_ID} -s /bin/sh ${USER})

# Deployment artifacts
COPY --link docker/app/entrypoint.sh /usr/local/bin/entrypoint
COPY --link docker/app/php.ini ${PHP_INI_DIR}/conf.d/99-php.ini
COPY --link docker/app/supercronic/laravel /etc/supercronic/laravel

RUN chmod +x /usr/local/bin/entrypoint && \
    mkdir -p \
        ${ROOT}/storage/framework/sessions \
        ${ROOT}/storage/framework/views \
        ${ROOT}/storage/framework/cache \
        ${ROOT}/storage/framework/testing \
        ${ROOT}/storage/logs \
        ${ROOT}/bootstrap/cache && \
    chown -R ${USER}:${GROUP} ${ROOT}

# tini = PID 1 (signal + zombie handling), entrypoint = runtime init, CMD default = octane
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint"]
CMD ["php", "artisan", "octane:frankenphp", "--host=0.0.0.0", "--port=8000"]

# ─── Composer deps (dev) ─────────────────────────────────────────────────────
FROM base AS composer-dev
WORKDIR /app
COPY --link composer.json composer.lock ./
RUN composer install --no-interaction --no-scripts --no-progress

# ─── Composer deps (production) ──────────────────────────────────────────────
FROM base AS composer-production
WORKDIR /app
COPY --link composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --no-autoloader --no-scripts --no-progress

# ─── Assets stage ────────────────────────────────────────────────────────────
# Uses base (PHP already installed) because @laravel/vite-plugin-wayfinder
# calls `php artisan wayfinder:generate` during `pnpm build`.
FROM base AS assets
USER root
WORKDIR /app

# Node + pnpm for frontend build (Alpine's nodejs lacks corepack — install pnpm via npm)
RUN apk add --no-cache nodejs npm && \
    rm -rf /var/cache/apk/* && \
    npm install -g pnpm@11.10.0

COPY --link package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile --ignore-scripts

# Composer deps needed for wayfinder:generate (no autoload yet — dump it)
COPY --link --from=composer-production /app/vendor ./vendor

# Copy all source + generate autoload + build
COPY --link . .
RUN composer dump-autoload --optimize --apcu --no-dev && \
    php artisan optimize --no-interaction && \
    pnpm run build && pnpm run build:ssr

# ─── Dev target ──────────────────────────────────────────────────────────────
FROM base AS dev

# XDebug + Node + pnpm for dev workflow
RUN apk add --no-cache \
    linux-headers autoconf make g++ nodejs npm && \
    pecl install xdebug && \
    docker-php-ext-enable xdebug && \
    apk del linux-headers autoconf make g++ && \
    rm -rf /var/cache/apk/* && \
    npm install -g pnpm@11.10.0

# Dev vendor (autoload included)
COPY --link --chown=${USER}:${GROUP} --from=composer-dev /app/vendor ./vendor

ENV XDEBUG_MODE=off

USER ${USER}
EXPOSE 8000 5173 9003

# ─── Production target ───────────────────────────────────────────────────────
FROM base AS production

ENV APP_ENV=production

# Production vendor
COPY --link --chown=${USER}:${GROUP} --from=composer-production /app/vendor ./vendor

# Built assets + SSR bundle
COPY --link --chown=${USER}:${GROUP} --from=assets /app/public/build ./public/build
COPY --link --chown=${USER}:${GROUP} --from=assets /app/storage/ssr ./storage/ssr

# Application source
COPY --link --chown=${USER}:${GROUP} . .

RUN composer dump-autoload --optimize --apcu --no-dev && \
    php artisan storage:link --no-interaction || true && \
    chown -R ${USER}:${GROUP} ${ROOT} && \
    find / -perm /6000 -type f -exec chmod a-s {} + 2>/dev/null || true

USER ${USER}
EXPOSE 8000
