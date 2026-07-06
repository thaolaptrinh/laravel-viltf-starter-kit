# Deployment Runbook

End-to-end production deploy guide. For Docker internals, see [`docker/README.md`](../docker/README.md).

## Architecture

```
Internet → Cloudflare (proxy, DDoS, edge TLS)
         → VPS :443 → Traefik (origin TLS via CF Origin Cert, HTTP/3)
                     ├── app :8000      (Octane/FrankenPHP, HTTP)
                     ├── reverb :8080   (WebSocket, /app prefix)
                     ├── horizon        (queue workers, no ingress)
                     ├── scheduler      (supercronic, no ingress)
                     └── ssr            (Inertia SSR, no ingress)
                     ├── pgsql :5432    (internal only)
                     └── redis :6379    (internal only)
```

Single image, 5 containers. Zero-downtime via `docker-rollout` (swaps container behind Traefik healthcheck).

## VPS Sizing

| Profile         | Specs                       | Use case               |
| --------------- | --------------------------- | ---------------------- |
| Minimum         | 2 vCPU / 4 GB / 30 GB SSD   | Staging, light prod    |
| **Recommended** | 2 vCPU / 6 GB / 40 GB SSD   | Production             |
| Heavy           | 4 vCPU / 8 GB+ / 60 GB+ SSD | High traffic, large DB |

Postgres config (`docker/postgres/postgresql.conf`) is tuned for 6 GB. Halve `shared_buffers`/`effective_cache_size` for 4 GB hosts.

---

## First-Time Deploy

### Step 0 — Local prep

```bash
export APP_DOMAIN=yourdomain.com
export GH_REPO=thaolaptrinh/laravel-viltf-starter-kit
export IMAGE=ghcr.io/thaolaptrinh/laravel-viltf
```

#### 0.1 GHCR PAT

https://github.com/settings/tokens → **Generate new token (classic)** with `write:packages`, `read:packages`. Save token.

```bash
echo "$GHCR_PAT" | docker login ghcr.io -u thaolaptrinh --password-stdin
```

#### 0.2 (skipped — CF Origin Cert generated on VPS)

Private key for TLS is generated **on the VPS** so it never touches your laptop. See Step 2.6.

#### 0.3 (skipped — `.env.production` generated on VPS)

Secrets (APP_KEY, DB/REDIS passwords, etc.) are generated **on the VPS**. See Step 2.5.

#### 0.4 Build + push image

```bash
make build-production            # multi-stage build, frontend included
docker tag $IMAGE:local $IMAGE:latest
docker push $IMAGE:latest
```

### Step 1 — Cloudflare DNS + SSL (automated)

```bash
make setup-vps-dns SSH_USER=$PRODUCTION_SSH_USER SSH_HOST=$PRODUCTION_SSH_HOST \
     CF_API_TOKEN=<zone-edit-token> APP_DOMAIN=$APP_DOMAIN
```

Creates A records (`yourdomain.com` + `traefik.yourdomain.com` → VPS IP, proxied) and sets SSL mode = **Full (strict)** + Always Use HTTPS. Idempotent.

Token scope: `Zone.Zone:Read`, `Zone.DNS:Edit`, `Zone.Settings:Edit` (separate from the Origin CA token used for cert generation).

### Step 2 — Provision VPS

```bash
export PRODUCTION_SSH_USER=root
export PRODUCTION_SSH_HOST=<VPS_IP>
export SSH_PRODUCTION=$PRODUCTION_SSH_USER@$PRODUCTION_SSH_HOST

# Docker + docker-rollout + clone repo + chown storage
make setup-vps SSH_USER=$PRODUCTION_SSH_USER SSH_HOST=$PRODUCTION_SSH_HOST

# GHCR login on VPS (for private image pull)
make setup-vps-ghcr-login SSH_USER=$PRODUCTION_SSH_USER SSH_HOST=$PRODUCTION_SSH_HOST \
     GH_USERNAME=thaolaptrinh GHCR_PAT=$GHCR_PAT
```

Verify:

```bash
ssh $SSH_PRODUCTION 'docker version && docker-rollout version && stat -c "%U:%G" /opt/app/storage'
# Must print: 1000:1000
```

### Step 2.5 — Generate `.env.production` on VPS

Secrets are generated on the VPS so they never touch your laptop.

```bash
ssh -t $SSH_PRODUCTION 'cd /opt/app && ./scripts/init-env.sh production'
```

Script prompts for `APP_DOMAIN`, then auto-generates:

- `APP_KEY`, `REVERB_APP_KEY`, `REVERB_APP_SECRET`
- `DB_PASSWORD`, `REDIS_PASSWORD` (24-char random)
- `TRAEFIK_AUTH` (bcrypt via `htpasswd` — auto-installs `apache2-utils` if missing)

All values are printed once + saved to `/opt/app/.env.production`. **Save them to a password manager** — the script won't show them again.

For staging, same flow: `./scripts/init-env.sh staging`.

### Step 2.6 — Generate CF Origin Cert on VPS

Private key for TLS is generated on the VPS so it never touches your laptop.

```bash
make setup-vps-cert SSH_USER=$PRODUCTION_SSH_USER SSH_HOST=$PRODUCTION_SSH_HOST \
     CF_API_TOKEN=<origin-ca-edit-token> APP_DOMAIN=$APP_DOMAIN
```

Verify:

```bash
ssh $SSH_PRODUCTION 'ls -la /opt/app/docker/traefik/certs/'
# cert.pem + private.key present
```

### Step 3 — Deploy

```bash
make deploy-production
```

The target auto-detects first-time vs subsequent:

- `app` not running → `docker compose up -d` (first-time)
- `app` running → `docker rollout` (zero-downtime)

Tail logs:

```bash
ssh $SSH_PRODUCTION 'cd /opt/app && COMPOSE_PROFILES=production docker compose -f compose.yaml -f compose.prod.yaml logs -f --tail=50'
```

### Step 4 — Migrate DB

```bash
make migrate-production
```

Runs `php artisan migrate --seed --force` inside the running app container. Explicit — only runs when you call it. No flag to remember to flip off.

### Step 5 — Verify

```bash
make verify-production
```

Or manual:

```bash
curl -fk https://yourdomain.com/up                        # "OK"
curl -k -u admin:PASSWORD https://traefik.yourdomain.com  # dashboard
```

---

## Subsequent Deploys

```bash
make release-production TAG=v1.0.0
# Runs: test → build → push → deploy

make migrate-production    # only if new migrations
make verify-production     # health check
```

---

## Rollback

```bash
make rollback-production TAG=sha-abcd12
# Re-creates containers with previous image, no service downtime
```

---

## Scale

```bash
make production-scale-up      # 2 app replicas
make production-scale-down    # 1 replica
```

Traefik load-balances across replicas via `/up` healthcheck.

---

## Backup (opt-in)

```bash
make backup-enable-production
```

- `pgdump` sidecar: daily 02:00 `pg_dump -Fc` → `pgdump` volume, 7-day retention
- `backup` container: tars `pgdump` → `./backups/backup-<ts>.tar.gz`, 7-day retention

Restore:

```bash
ssh $SSH_PRODUCTION 'cd /opt/app && \
    docker run --rm -v stack-pgsql:/restore -v $(pwd)/backups:/bk alpine \
    tar xzf /bk/backup-<ts>.tar.gz -C /restore'
# Then: pg_restore -d $DB_DATABASE /restore/dump/*.pgc
```

---

## Troubleshooting

| Symptom                              | Cause                             | Fix                                                                                               |
| ------------------------------------ | --------------------------------- | ------------------------------------------------------------------------------------------------- |
| `pull access denied for ghcr.io`     | Image private, VPS not logged in  | `make setup-vps-ghcr-login`                                                                       |
| Too many redirects                   | Cloudflare SSL = Flexible         | `make setup-vps-dns` sets Full (strict) automatically                                             |
| TLS handshake failed                 | CF Origin Cert expired / missing  | Regenerate: `make setup-vps-cert`                                                                 |
| `permission denied: storage/logs`    | Host `storage/` not owned by 1000 | `setup-vps.sh` handles it; if not: `chown -R 1000:1000 /opt/app/storage /opt/app/bootstrap/cache` |
| 502 / 503 from Traefik               | App container unhealthy           | `docker compose logs app`, check `/up` returns 200                                                |
| Schema out of date                   | Forgot to migrate after deploy    | `make migrate-production`                                                                         |
| `htpasswd: command not found`        | Local missing apache2-utils       | `init-env.sh` auto-installs; manual: `apt install apache2-utils`                                  |
| Container OOM killed                 | Memory limit too low              | Raise `APP_MEM_LIMIT` in `.env.production`                                                        |
| Octane stale config after env change | Cached config persists in worker  | `make reload-production` (runs `octane:reload`)                                                   |

### Inspect running state

```bash
make verify-production                   # one-shot health check
make reload-production                   # clear Octane cached state
ssh $SSH_PRODUCTION 'cd /opt/app && COMPOSE_PROFILES=production docker compose -f compose.yaml -f compose.prod.yaml logs -f --tail=100'
```

---

## Security Checklist

- [x] Non-root container user (`UID 1000`)
- [x] `no-new-privileges:true` on every service
- [x] SUID/SGID bits stripped in production image (`find / -perm /6000 -type f -exec chmod a-s {} +`)
- [x] Supervisor RPC over unix socket (chmod 0600), no inet listener
- [x] Traefik dashboard behind basic auth + TLS
- [x] HSTS 2 years, `includeSubdomains`, `preload`
- [x] TLS 1.2+ with strict cipher list, `sniStrict`
- [x] Security headers: `X-Content-Type-Options`, `X-Frame-Options: SAMEORIGIN`, `Referrer-Policy`, `Permissions-Policy`
- [x] `expose_php = Off`
- [x] UFW firewall on VPS (allow 22/80/443 only — `setup-vps.sh`)
- [ ] **Manual**: rotate GHCR PAT yearly
- [ ] **Manual**: rotate CF Origin Cert every 15 years (validity window)
- [ ] **Manual**: verify backup restore quarterly
