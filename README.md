# Laravel VILT-F Starter Kit

A Laravel starter kit with Vue, Inertia, Livewire, Filament, Tailwind CSS, and TypeScript. Powered by FrankenPHP + Octane for maximum performance.

## Prerequisites

- **Docker** (with Compose v2.20+)
- **GNU Make**
- **Git**

No local PHP/Composer/Node.js needed — everything runs in containers.

## Quick Start

```bash
git clone https://github.com/thaolaptrinh/laravel-viltf-starter-kit.git
cd laravel-viltf-starter-kit
make install
```

This will:

1. Copy `.env.example` → `.env`
2. Build the dev Docker image (PHP 8.5 + FrankenPHP + Octane)
3. Install composer + pnpm dependencies inside container
4. Start dev environment (app + horizon + pgsql + redis)

Open: <http://localhost:8080>

## Common Commands

```bash
make help              # list all commands
make dev               # start dev environment
make dev-stop          # stop containers
make dev-down          # stop & remove containers
make dev-logs          # tail logs
make artisan CMD="migrate"          # artisan commands
make pnpm CMD="install"             # pnpm commands
make exec CMD="sh"                  # shell in container
make test               # run tests (isolated testing env)
make tinker             # tinker
make fresh              # migrate:fresh --seed
make db-shell           # PostgreSQL shell
make redis-shell        # Redis CLI
make status             # container health
make lint               # run linters
make clean              # remove all containers + volumes
```

## Architecture

| Component  | Technology                           |
| ---------- | ------------------------------------ |
| Runtime    | PHP 8.5 + FrankenPHP 1.12.4 (Alpine) |
| Server     | Laravel Octane (FrankenPHP driver)   |
| Queue      | Laravel Horizon (Redis)              |
| WebSocket  | Laravel Reverb                       |
| SSR        | Inertia.js SSR (Node)                |
| Database   | PostgreSQL 18                        |
| Cache      | Redis 7                              |
| Edge Proxy | Traefik v3.6 + Cloudflare            |
| Deploy     | docker-rollout (zero-downtime)       |

### Services

Single immutable image, multiple containers. Compose decides each service's role via `command:` — no entrypoint dispatch, no Supervisor in production.

| Service           | Command             | Purpose                                       |
| ----------------- | ------------------- | --------------------------------------------- |
| `app`             | `octane:frankenphp` | Serve web requests (HTTP)                     |
| `horizon`         | `horizon`           | Queue workers + dashboard                     |
| `scheduler`       | `supercronic`       | Cron jobs                                     |
| `ssr`             | `inertia:start-ssr` | Inertia SSR rendering                         |
| `reverb`          | `reverb:start`      | WebSocket server                              |
| `vite` (dev only) | `pnpm dev`          | Vite HMR — separate service for log isolation |

### Environments

| Profile        | Compose files                            | Services                                                    |
| -------------- | ---------------------------------------- | ----------------------------------------------------------- |
| **dev**        | `compose.yaml` + `compose.override.yaml` | app, horizon, vite, pgsql, redis                            |
| **staging**    | `compose.yaml` + `compose.staging.yaml`  | app, horizon, scheduler, ssr, reverb, pgsql, redis, traefik |
| **production** | `compose.yaml` + `compose.prod.yaml`     | same as staging + backup (opt-in)                           |
| **testing**    | `compose.yaml` + `compose.test.yaml`     | app (isolated DB, sync queue)                               |

## Production Deployment

See [`DEPLOYMENT.md`](DEPLOYMENT.md) for the full runbook. Quick reference:

### First-time VPS setup

```bash
# 1. Local: build + push image (after `docker login ghcr.io`)
make build-production && make push-production

# 2. VPS: provision (Docker + UFW + docker-rollout + repo + storage perms)
make setup-vps SSH_USER=root SSH_HOST=<IP>

# 3. VPS: GHCR login
make setup-vps-ghcr-login SSH_USER=root SSH_HOST=<IP> GH_USERNAME=... GHCR_PAT=...

# 4. VPS: CF Origin Cert
make setup-vps-cert SSH_USER=root SSH_HOST=<IP> CF_API_TOKEN=... APP_DOMAIN=...

# 5. VPS: CF DNS records + SSL Full(strict)
make setup-vps-dns SSH_USER=root SSH_HOST=<IP> CF_API_TOKEN=... APP_DOMAIN=...

# 6. VPS: generate .env.production (auto-secrets)
make init-env-production SSH_USER=root SSH_HOST=<IP>

# 7. Deploy (auto-detects first-time → up -d, subsequent → zero-downtime rollout)
make deploy-production SSH_PRODUCTION=root@<IP>

# 8. Migrate + verify
make migrate-production SSH_PRODUCTION=root@<IP>
make verify-production SSH_PRODUCTION=root@<IP> APP_DOMAIN=...
```

### Subsequent deploys

```bash
make release-production TAG=v1.0.0 SSH_PRODUCTION=root@<IP>   # test → build → push → deploy
make migrate-production SSH_PRODUCTION=root@<IP>               # only if new migrations
```

### Rollback

```bash
make rollback-production TAG=sha-abcd12
```

### Scale

```bash
make production-scale-up    # 2 replicas
make production-scale-down  # 1 replica
```

## VPS Sizing

| Profile         | Specs                       | Use case               |
| --------------- | --------------------------- | ---------------------- |
| Minimum         | 2 vCPU / 4 GB / 30 GB SSD   | Dev/stg, light prod    |
| **Recommended** | 2 vCPU / 6 GB / 40 GB SSD   | Production             |
| Heavy           | 4 vCPU / 8 GB+ / 60 GB+ SSD | High traffic, large DB |

## Testing

Tests run in an isolated environment with separate DB, sync queue, and array cache:

```bash
make test                              # all unit + feature tests
make test CMD="--filter=UserTest"      # specific test
```

A pre-push hook (`.githooks/pre-push`) blocks pushes if tests fail.

## License

[MIT](LICENSE)
