SHELL := /bin/bash
-include .env
export $(shell sed 's/=.*//' .env)
APP_NAME = sockets

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
	docker-compose up -d $(APP_NAME)

down: ## Stop the app
	@docker-compose down

lint:
	semgrep -q --strict --timeout=0 --config=p/ci --lang=javascript src/index.js
	semgrep -q --strict --timeout=0 --config=p/nodejsscan --lang=javascript src/index.js

package: prep
	tar --exclude '*.DS_Store' -cf $(APP_NAME).tar src
	tar -rf $(APP_NAME).tar package.json
	gzip -f9 $(APP_NAME).tar
	ls -l --block-size=M $(APP_NAME).tar.gz

package-upload:
	$(CMD_AWS) --profile trivialsec s3 cp --only-show-errors $(APP_NAME).tar.gz s3://static-trivialsec/deploy-packages/$(COMMON_VERSION)/$(APP_NAME).tar.gz

package-dev: package
	$(CMD_AWS) --profile minio --endpoint-url http://localhost:9000 s3 cp --only-show-errors $(APP_NAME).tar.gz s3://static-trivialsec/deploy-packages/$(COMMON_VERSION)/$(APP_NAME).tar.gz
