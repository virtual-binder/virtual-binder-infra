.DEFAULT_GOAL := help

.PHONY: help dev install up api db web mobile down logs status config

help: ## Muestra los comandos disponibles
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z_-]+:.*## / {printf "%-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

dev: ## Levanta PostgreSQL, API, web y Expo
	@./scripts/dev.sh

install: ## Instala dependencias de web y móvil
	@cd ../virtual-binder-web && npm install
	@cd ../virtual-binder-mobile && npm install

up: ## Construye y levanta PostgreSQL y la API en segundo plano
	@docker compose up --build -d api db

api: ## Levanta PostgreSQL y la API con logs en primer plano
	@docker compose up --build api db

db: ## Levanta únicamente PostgreSQL
	@docker compose up db

web: ## Inicia Next.js
	@cd ../virtual-binder-web && npm run dev

mobile: ## Inicia Expo
	@cd ../virtual-binder-mobile && npm start

down: ## Detiene los contenedores conservando los datos
	@docker compose down

logs: ## Muestra los logs de PostgreSQL y la API
	@docker compose logs -f api db

status: ## Muestra el estado de los contenedores
	@docker compose ps

config: ## Valida la configuración de Compose
	@docker compose config --quiet
