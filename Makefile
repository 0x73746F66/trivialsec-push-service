SHELL := /bin/bash
-include .env
export $(shell sed 's/=.*//' .env)

.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help
CMD_AWS := aws
ifdef AWS_PROFILE
CMD_AWS += --profile $(AWS_PROFILE)
endif
ifdef AWS_REGION
CMD_AWS += --region $(AWS_REGION)
endif

prep:
	find . -type f -name '*.DS_Store' -delete 2>/dev/null || true
	@rm *.zip || true

build: ## Build compressed container
	docker-compose build

buildnc: package-dev ## Clean build docker
	docker-compose build --no-cache

rebuild: down build

docker-clean: ## Fixes some issues with docker
	docker rmi $(docker images -qaf "dangling=true")
	yes | docker system prune
	sudo service docker restart

docker-purge: ## tries to compeltely remove all docker files and start clean
	docker rmi $(docker images -qa)
	yes | docker system prune
	sudo service docker stop
	sudo rm -rf /tmp/docker.backup/
	sudo cp -Pfr /var/lib/docker /tmp/docker.backup
	sudo rm -rf /var/lib/docker
	sudo service docker start

up: ## Start the app
	docker-compose up -d

down: ## Stop the app
	@docker-compose down --remove-orphans

lint:
	semgrep -q --strict --timeout=0 --config=p/ci --lang=javascript src/index.js
	semgrep -q --strict --timeout=0 --config=p/nodejsscan --lang=javascript src/index.js
