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
