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

| Component | Technology |
|---|---|
| Runtime | PHP 8.5 + FrankenPHP 1.12.4 (Alpine) |
| Server | Laravel Octane (FrankenPHP driver) |
| Queue | Laravel Horizon (Redis) |
| WebSocket | Laravel Reverb |
| SSR | Inertia.js SSR (Node) |
| Database | PostgreSQL 18 |
| Cache | Redis 7 |
| Edge Proxy | Traefik v3.6 + Cloudflare |
| Deploy | docker-rollout (zero-downtime) |

### Container Modes

Single Docker image, 5 runtime modes via `CONTAINER_MODE`:

| Mode | Command | Purpose |
|---|---|---|
| `http` | `octane:frankenphp` | Serve web requests |
| `horizon` | `horizon` | Queue workers + dashboard |
| `scheduler` | `supercronic` | Cron jobs |
| `ssr` | `inertia:start-ssr` | Inertia SSR rendering |
| `reverb` | `reverb:start` | WebSocket server |

### Environments

| Profile | Compose files | Services |
|---|---|---|
| **dev** | `compose.yaml` + `compose.override.yml` | app, horizon, pgsql, redis |
| **staging** | `compose.yaml` + `compose.staging.yml` | app, horizon, scheduler, ssr, reverb, pgsql, redis, traefik |
| **production** | `compose.yaml` + `compose.production.yml` | same as staging + backup (opt-in) |
| **testing** | `compose.yaml` + `compose.testing.yml` | app (isolated DB, sync queue) |

## Production Deployment

### First-time VPS setup (7 commands, 0 manual dashboard)

```bash
# 1. Create env files
make init-env-production
# Edit .env.production with real secrets

# 2. Generate CF Origin Cert (interactive prompt)
make setup-cf-cert

# 3. Provision VPS (installs Docker, docker-rollout, clones repo)
make setup-vps

# 4. GHCR login on VPS
make setup-vps-login

# 5. Upload certs + env
make upload-certs
make upload-env-production

# 6. Build + push image
make push-production

# 7. Deploy (zero-downtime)
make deploy-production
```

### Subsequent deploys

```bash
make release-production   # test → build → push → deploy (1 command)
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

| Profile | Specs | Use case |
|---|---|---|
| Minimum | 2 vCPU / 4 GB / 40 GB | Dev/stg, light prod |
| **Recommended** | 2 vCPU / 6 GB / 60 GB | Production |
| Heavy | 4 vCPU / 8 GB+ / 120 GB | High traffic |

## Testing

Tests run in an isolated environment with separate DB, sync queue, and array cache:

```bash
make test                              # all unit + feature tests
make test CMD="--filter=UserTest"      # specific test
```

A pre-push hook (`.githooks/pre-push`) blocks pushes if tests fail.

## License

[MIT](LICENSE)
