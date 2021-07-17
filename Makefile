SHELL := /bin/bash
-include .env
export $(shell sed 's/=.*//' .env)

.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

prep:
	find . -type f -name '*.DS_Store' -delete 2>/dev/null || true
	@rm *.zip || true

build: ## Build compressed container
	docker-compose build

buildnc: package ## Clean build docker
	docker-compose build --no-cache

rebuild: down build

up: ## Start the app
	docker-compose up -d

down: ## Stop the app
	@docker-compose down --remove-orphans

lint:
	semgrep -q --strict --timeout=0 --config=p/r2c-ci --lang=javascript src/index.js
	semgrep -q --strict --timeout=0 --config=p/nodejsscan --lang=javascript src/index.js
