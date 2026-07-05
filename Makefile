.DEFAULT_GOAL := help
.PHONY: help install \
        dev dev-stop dev-down dev-logs dev-rebuild \
        staging production stg prod staging-logs production-logs staging-down production-down \
        build build-production \
        push-staging push-production deploy-staging deploy-production \
        release-staging release-production rollout-staging rollout-production production-scale-up production-scale-down \
        reload-staging reload-production rollback-production \
        artisan pnpm composer exec shell tinker db-shell redis-shell lint status \
        init-env-staging init-env-production \
        setup-cf-cert setup-vps setup-vps-login \
        upload-certs upload-env-staging upload-env-production \
        test fresh \
        clean

IMAGE ?= ghcr.io/thaolaptrinh/laravel-viltf
COMPOSE_DEV  = COMPOSE_PROFILES=dev  docker compose
COMPOSE_STAGING  = COMPOSE_PROFILES=staging  docker compose -f compose.yaml -f compose.staging.yml
COMPOSE_PRODUCTION = COMPOSE_PROFILES=production docker compose -f compose.yaml -f compose.production.yml
COMPOSE_TEST = COMPOSE_PROFILES=testing docker compose -f compose.yaml -f compose.testing.yml

# SSH config (set in .env or ~/.ssh/config)
SSH_STAGING ?= $(STAGING_SSH_USER)@$(STAGING_SSH_HOST)
SSH_PRODUCTION ?= $(PRODUCTION_SSH_USER)@$(PRODUCTION_SSH_HOST)
APP_DIR ?= /opt/app

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

install-rollout: ## Install docker-rollout CLI plugin (required for zero-downtime deploys)
	@if [ -x ~/.docker/cli-plugins/docker-rollout ]; then \
		echo "docker-rollout already installed"; \
	else \
		echo "Installing docker-rollout..."; \
		mkdir -p ~/.docker/cli-plugins; \
		curl -fsSL https://raw.githubusercontent.com/wowu/docker-rollout/master/docker-rollout \
			-o ~/.docker/cli-plugins/docker-rollout; \
		chmod +x ~/.docker/cli-plugins/docker-rollout; \
		echo "docker-rollout installed to ~/.docker/cli-plugins/"; \
	fi

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

build-production: ## Pre-build assets + build production image
	pnpm run build && pnpm run build:ssr
	docker build --target=production -t $(IMAGE):local -f Dockerfile .

# ─── VPS Automation (scripts/ wrappers) ───────────────────────────────────

init-env-staging: ## Create .env.staging from template
	@[ -f .env.staging ] || cp .env.staging.example .env.staging
	@echo "⚠️  Edit .env.staging with real secrets"

init-env-production: ## Create .env.production from template
	@[ -f .env.production ] || cp .env.production.example .env.production
	@echo "⚠️  Edit .env.production with real secrets"

setup-cf-cert: ## Generate CF Origin Cert via API (interactive or CF_API_TOKEN= APP_DOMAIN=)
	APP_DOMAIN="$(APP_DOMAIN)" CF_API_TOKEN="$(CF_API_TOKEN)" ./scripts/setup-cf-cert.sh

setup-vps: ## Provision VPS: Docker + docker-rollout + clone (interactive or SSH_USER= SSH_HOST=)
	SSH_USER="$(SSH_USER)" SSH_HOST="$(SSH_HOST)" GH_REPO="$(GH_REPO)" APP_DIR="$(APP_DIR)" ./scripts/setup-vps.sh

setup-vps-login: ## GHCR login on VPS (interactive or SSH_USER= SSH_HOST= GHCR_PAT= GH_USERNAME=)
	SSH_USER="$(SSH_USER)" SSH_HOST="$(SSH_HOST)" GHCR_PAT="$(GHCR_PAT)" GH_USERNAME="$(GH_USERNAME)" ./scripts/setup-vps-login.sh

upload-certs: ## SCP certs to VPS (interactive or SSH_USER= SSH_HOST=)
	SSH_USER="$(SSH_USER)" SSH_HOST="$(SSH_HOST)" APP_DIR="$(APP_DIR)" ./scripts/upload.sh certs

upload-env-staging: ## SCP .env.staging to VPS (interactive or SSH_USER= SSH_HOST=)
	SSH_USER="$(SSH_USER)" SSH_HOST="$(SSH_HOST)" APP_DIR="$(APP_DIR)" ./scripts/upload.sh env-staging

upload-env-production: ## SCP .env.production to VPS (interactive or SSH_USER= SSH_HOST=)
	SSH_USER="$(SSH_USER)" SSH_HOST="$(SSH_HOST)" APP_DIR="$(APP_DIR)" ./scripts/upload.sh env-production

# ─── Deploy (zero-downtime via docker-rollout) ──────────────────────────────

# ── Push to GHCR (requires `docker login ghcr.io` once) ────────────────────

push-staging: ## Build + tag + push :staging to GHCR
	make build-production
	docker tag $(IMAGE):local $(IMAGE):staging
	docker push $(IMAGE):staging
	@echo "Pushed $(IMAGE):staging"

push-production: ## Build + tag + push :latest + :$(TAG) to GHCR
	make build-production
	docker tag $(IMAGE):local $(IMAGE):latest
	docker push $(IMAGE):latest
	@if [ -n "$(TAG)" ]; then \
		docker tag $(IMAGE):local $(IMAGE):$(TAG); \
		docker push $(IMAGE):$(TAG); \
		echo "Pushed $(IMAGE):$(TAG)"; \
	fi
	@echo "Pushed $(IMAGE):latest"

# ── Deploy via SSH + docker-rollout ────────────────────────────────────────

deploy-staging: ## SSH → pull → rollout staging
	ssh $(SSH_STAGING) '\
		cd $(APP_DIR) && \
		COMPOSE_PROFILES=staging docker compose -f compose.yaml -f compose.staging.yml pull && \
		COMPOSE_PROFILES=staging docker rollout -f compose.yaml -f compose.staging.yml app && \
		COMPOSE_PROFILES=staging docker rollout -f compose.yaml -f compose.staging.yml horizon && \
		COMPOSE_PROFILES=staging docker rollout -f compose.yaml -f compose.staging.yml ssr && \
		COMPOSE_PROFILES=staging docker rollout -f compose.yaml -f compose.staging.yml reverb && \
		COMPOSE_PROFILES=staging docker compose -f compose.yaml -f compose.staging.yml up -d --remove-orphans scheduler traefik && \
		COMPOSE_PROFILES=staging docker compose -f compose.yaml -f compose.staging.yml exec -T app php artisan octane:reload && \
		docker image prune -f'

deploy-production: ## SSH → pull → rollout production
	ssh $(SSH_PRODUCTION) '\
		cd $(APP_DIR) && \
		COMPOSE_PROFILES=production docker compose -f compose.yaml -f compose.production.yml pull && \
		COMPOSE_PROFILES=production docker rollout -f compose.yaml -f compose.production.yml app && \
		COMPOSE_PROFILES=production docker rollout -f compose.yaml -f compose.production.yml horizon && \
		COMPOSE_PROFILES=production docker rollout -f compose.yaml -f compose.production.yml ssr && \
		COMPOSE_PROFILES=production docker rollout -f compose.yaml -f compose.production.yml reverb && \
		COMPOSE_PROFILES=production docker compose -f compose.yaml -f compose.production.yml up -d --remove-orphans scheduler traefik && \
		COMPOSE_PROFILES=production docker compose -f compose.yaml -f compose.production.yml exec -T app php artisan octane:reload && \
		docker image prune -f'

# ── Release pipeline (test → build → push → deploy) ────────────────────────

release-staging: ## test → build → push → upload → deploy staging
	@echo "━━━ Test ━━━"
	make test
	@echo "━━━ Build + Push ━━━"
	make push-staging
	@echo "━━━ Upload + Deploy ━━━"
	scp -q .env.staging $(SSH_STAGING):$(APP_DIR)/.env.staging || true
	scp -q -r docker/traefik/certs/ $(SSH_STAGING):$(APP_DIR)/docker/traefik/certs/ || true
	make deploy-staging
	@echo "━━━ Done ━━━"

release-production: ## test → build → push → upload → deploy production [TAG=v1.0.0]
	@echo "━━━ Test ━━━"
	make test
	@echo "━━━ Build + Push ━━━"
	make push-production TAG=$(TAG)
	@echo "━━━ Upload + Deploy ━━━"
	scp -q .env.production $(SSH_PRODUCTION):$(APP_DIR)/.env.production || true
	scp -q -r docker/traefik/certs/ $(SSH_PRODUCTION):$(APP_DIR)/docker/traefik/certs/ || true
	make deploy-production
	@echo "━━━ Done ━━━"

# ── Legacy targets (keep for compatibility) ────────────────────────────────

rollout-staging: ## Zero-downtime deploy staging (legacy — prefer release-staging)
	$(COMPOSE_STAGING) pull
	$(COMPOSE_STAGING) docker rollout -f compose.yaml -f compose.staging.yml app
	$(COMPOSE_STAGING) docker rollout -f compose.yaml -f compose.staging.yml horizon
	$(COMPOSE_STAGING) docker rollout -f compose.yaml -f compose.staging.yml ssr
	$(COMPOSE_STAGING) docker rollout -f compose.yaml -f compose.staging.yml reverb
	$(COMPOSE_STAGING) up -d --remove-orphans scheduler traefik
	$(COMPOSE_STAGING) exec -T app php artisan octane:reload

rollout-production: ## Zero-downtime deploy production (legacy — prefer release-production)
	$(COMPOSE_PRODUCTION) pull
	$(COMPOSE_PRODUCTION) docker rollout -f compose.yaml -f compose.production.yml app
	$(COMPOSE_PRODUCTION) docker rollout -f compose.yaml -f compose.production.yml horizon
	$(COMPOSE_PRODUCTION) docker rollout -f compose.yaml -f compose.production.yml ssr
	$(COMPOSE_PRODUCTION) docker rollout -f compose.yaml -f compose.production.yml reverb
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

db-shell: ## PostgreSQL shell (psql)
	$(COMPOSE_DEV) exec pgsql psql -U $${DB_USERNAME:-laravel} -d $${DB_DATABASE:-laravel}

redis-shell: ## Redis CLI shell
	$(COMPOSE_DEV) exec redis redis-cli

lint: ## Run linters (Pint + Rector + ESLint)
	$(COMPOSE_DEV) exec app composer lint

status: ## Show container health status
	@$(COMPOSE_DEV) ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}'

rollback-production: ## Rollback production to previous image (TAG=v1.0.0)
	@test -n "$(TAG)" || { echo "❌ Usage: make rollback-production TAG=sha-abcd12"; exit 1; }
	@echo "⏪ Rolling back to $(TAG)..."
	ssh $(SSH_PRODUCTION) '\
		cd $(APP_DIR) && \
		COMPOSE_PROFILES=production IMAGE_TAG=$(TAG) docker compose -f compose.yaml -f compose.production.yml up -d --no-deps app horizon ssr reverb && \
		COMPOSE_PROFILES=production docker compose -f compose.yaml -f compose.production.yml exec -T app php artisan octane:reload'
	@echo "✅ Rolled back to $(TAG)"

test: ## Run tests in isolated testing env: make test CMD="--filter=TestName"
	$(COMPOSE_TEST) up -d --wait pgsql redis
	$(COMPOSE_TEST) run --rm app php artisan test --testsuite=Feature $(CMD)
	$(COMPOSE_TEST) down

fresh: ## Migrate fresh + seed
	$(COMPOSE_DEV) exec app php artisan migrate:fresh --seed

clean: ## Remove all containers, volumes, images
	$(COMPOSE_DEV) down -v --rmi local || true
	$(COMPOSE_STAGING) down -v --rmi local || true
	$(COMPOSE_PRODUCTION) down -v --rmi local || true
