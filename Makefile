SHELL := /bin/bash
-include .env
export $(shell sed 's/=.*//' .env)

.PHONY: up

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

build: ## Build compressed container
	docker-compose build --compress sockets

buildnc: ## Clean build docker
	docker-compose build --no-cache --compress sockets

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
	docker-compose up -d sockets

down: ## Stop the app
	docker-compose stop sockets
	yes|docker-compose rm sockets

package:
	zip -9rq sockets.zip src -x '*.pyc' -x '__pycache__' -x '*.DS_Store'
	zip -uj9q sockets.zip package.json

package-upload: package
	$(CMD_AWS) s3 cp $(PKG_PATH)/sockets.zip s3://cloudformation-trivialsec/deploy-packages/sockets-$(COMMON_VERSION).zip
