# Docker Internals

Reference for the Docker setup. For deploy workflow, see [`../DEPLOYMENT.md`](../DEPLOYMENT.md).

## Design Principles

1. **Single immutable image** — one image per environment, no runtime role switch
2. **Compose as orchestrator** — `command:` decides each service's role (Single Source of Truth)
3. **`tini` as PID 1** — reaps zombies + forwards signals correctly
4. **No Supervisor in production** — each container runs exactly one process; `restart: unless-stopped` + `stop_grace_period` handle lifecycle
5. **Build-time artifacts** — `optimize`, `view:cache`, frontend assets baked into production image

## Directory Layout

```
docker/
├── app/                     # Application image assets (baked into image)
│   ├── entrypoint.sh        # ENTRYPOINT — storage:link + exec "$@"
│   ├── php.ini              # PHP / Opcache / JIT config
│   ├── supercronic/laravel  # Cron schedule (1/min → schedule:run)
│   └── frankenphp/Caddyfile # Used when running octane without supervisor
├── postgres/                # Postgres runtime config (mounted)
│   └── postgresql.conf
├── redis/                   # Redis runtime config (mounted, when needed)
└── traefik/                 # Traefik runtime (mounted)
    ├── traefik.yml          # Static config (entrypoints, providers)
    ├── dynamic.yml          # Dynamic config (TLS, middlewares, auth)
    └── certs/               # CF Origin Cert (gitignored)
```

**Pattern:** one folder per service/image. Maps 1:1 to Compose services.

## Dockerfile Stages

```
composer-binary ─────┐
                     ├──► base ──┬──► composer-dev ──────► dev
frankenphp:alpine ───┘           ├──► composer-production ─► production
                                 └──► (production target)
node:alpine ──────────────────────► assets ──────────────► (production target)
```

| Stage                 | Purpose                                                                               |
| --------------------- | ------------------------------------------------------------------------------------- |
| `composer-binary`     | Source of `composer` executable, copied into `base`                                   |
| `base`                | PHP 8.5 + extensions + supercronic + `tini` + non-root user                           |
| `composer-dev`        | `composer install` (with dev deps, autoload generated)                                |
| `composer-production` | `composer install --no-dev --no-autoloader`                                           |
| `assets`              | `pnpm install` + `pnpm run build && build:ssr` → emits `public/build` + `storage/ssr` |
| `dev`                 | base + xdebug + node + pnpm + dev vendor                                              |
| `production`          | base + production vendor + built assets + `optimize` cache                            |

### Build args

| Arg                    | Default  | Notes                               |
| ---------------------- | -------- | ----------------------------------- |
| `PHP_VERSION`          | `8.5`    |                                     |
| `FRANKENPHP_VERSION`   | `1.12.4` |                                     |
| `COMPOSER_VERSION`     | `2.8`    |                                     |
| `NODE_VERSION`         | `22`     |                                     |
| `USER_ID` / `GROUP_ID` | `1000`   | Match host UID for bind-mount perms |
| `TZ`                   | `UTC`    |                                     |

## Entrypoint

Minimal init, then `exec "$@"` so the process becomes the foreground child of `tini`:

```sh
php artisan storage:link   # idempotent symlink
chown storage/ cache/      # only if running as root (dev safety net)
exec "$@"
```

**No**: dispatch on env, `optimize`, `migrate`, conditional logic. Those are build-time or compose-time concerns.

## Services

Compose decides each service's role via `command:`:

| Service      | Command                                | Notes                                                    |
| ------------ | -------------------------------------- | -------------------------------------------------------- |
| `app`        | `php artisan octane:frankenphp`        | HTTP, exposes `:8000`                                    |
| `horizon`    | `php artisan horizon`                  | `stop_grace_period: 3600s` for worker drain              |
| `scheduler`  | `supercronic /etc/supercronic/laravel` | Designed for PID 1                                       |
| `ssr`        | `php artisan inertia:start-ssr`        | Node runtime                                             |
| `reverb`     | `php artisan reverb:start`             | `ulimits.nofile: 65536`                                  |
| `vite` (dev) | `pnpm dev --host`                      | Separate service for log isolation + independent restart |

### Process lifecycle

- **Crash recovery**: `restart: unless-stopped` (Docker recreates container in ~3-10s; Traefik healthcheck fails over to replicas if scaled)
- **Graceful shutdown**: SIGTERM → process drains → exits; `stop_grace_period` per-service; Docker SIGKILLs after grace
- **Zombie reaping**: `tini` (PID 1) handles this; Laravel command is the foreground child

## PHP Runtime

`php.ini` highlights:

- `memory_limit = 256M`, `max_execution_time = 60`, `max_input_time = 60`
- `upload_max_filesize = 400M`, `post_max_size = 420M`
- Opcache: 256 MB, 32531 files, `validate_timestamps=0` (rely on `octane:reload`)
- JIT: `tracing` mode, 128 MB buffer
- APCu enabled (Laravel config/routes cache)

## Compose File Hierarchy

```
compose.yaml                    # base — services, volumes, networks (profile-gated)
├── compose.override.yaml     # auto-loaded for dev (Vite service, XDEBUG_MODE)
├── compose.test.yaml         # CI / `make test` (isolated DB, sync queue)
├── compose.staging.yaml         # staging (image pull, traefik, TLS)
└── compose.prod.yaml      # production (image pull, traefik, backup, ulimits)
```

### Merge rules to know

- `volumes` and `ports` **append** across files. Production/staging anchors use `!reset []` to wipe dev bind-mounts (`.:/var/www/html`) so prod runs only image-baked code.
- `build: !reset null` in prod/staging forces image pull, never local build.

### Profiles

| Profile             | Services                                                    |
| ------------------- | ----------------------------------------------------------- |
| `dev`               | app, horizon, vite, pgsql, redis                            |
| `staging`           | app, horizon, scheduler, ssr, reverb, pgsql, redis, traefik |
| `production`        | same as staging                                             |
| `production,backup` | adds `backup` + `pgdump` sidecars                           |
| `testing`           | app (isolated), pgsql                                       |

## Traefik

Mounted at runtime from `docker/traefik/`:

- **`traefik.yml`**: entrypoints `:80` (redirect→443), `:443` (HTTP/3), `:8080` (dashboard); Docker provider scoped to `stack` network.
- **`dynamic.yml`**: TLS 1.2+ with strict ciphers, security headers (HSTS 2y), compression, basic-auth for dashboard.
- **`certs/`**: Cloudflare Origin Cert (`cert.pem` + `private.key`), gitignored. Generate via `make setup-vps-cert`.

Traffic flow:

```
Internet → Cloudflare (proxy) → Traefik :443 → app :8000 (Octane)
                                            → reverb :8080 (PathPrefix /app)
```

## Backup

Two sidecars under profile `production,backup`:

- `pgdump` (postgres:18-alpine): cron `pg_dump -Fc` → shared volume `pgdump:/dump` with 7-day retention.
- `backup` (offen/docker-volume-backup): tars `pgdump` volume + any others → `./backups/backup-<ts>.tar.gz`, pruned after 7 days.

Never back up the live `stack-pgsql` volume directly — file-level snapshot of a running Postgres is corrupt.

## Volumes

| Volume                        | Purpose                             | Persistence          |
| ----------------------------- | ----------------------------------- | -------------------- |
| `stack-pgsql`                 | Postgres data                       | Permanent            |
| `stack-redis`                 | Redis AOF + RDB                     | Permanent            |
| `pgdump`                      | Dump staging area for backup        | Ephemeral            |
| `./storage` (bind, prod only) | User uploads, logs, framework cache | Permanent (host dir) |

Volume names parameterized via `VOLUME_PREFIX` (default `stack`) — set per-env to avoid sharing data across staging/prod on same host.

## Healthchecks

Only `app` service defines a healthcheck (curl `/up`) — used by Traefik routing + `depends_on` ordering. Other services rely on `restart: unless-stopped` for crash recovery.
