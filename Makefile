# minimalistic utility to test and develop locally

SHELL = /bin/sh
.DEFAULT_GOAL := help
MAKEFLAGS += -j3

export DOCKER_IMAGE_NAME ?= osparc-dakota
export DOCKER_IMAGE_TAG ?= 0.0.1

define _bumpversion
	# upgrades as $(subst $(1),,$@) version, commits and tags
	@docker run -it --rm -v $(PWD):/${DOCKER_IMAGE_NAME} \
		-u $(shell id -u):$(shell id -g) \
		itisfoundation/ci-service-integration-library:v1.0.1-dev-33 \
		sh -c "cd /${DOCKER_IMAGE_NAME} && bump2version --verbose --list --config-file $(1) $(subst $(2),,$@)"
endef

.PHONY: version-patch version-minor version-major
version-patch version-minor version-major: .bumpversion.cfg ## increases service's version
	@make compose-spec
	@$(call _bumpversion,$<,version-)
	@make compose-spec

.PHONY: compose-spec
compose-spec: ## runs ooil to assemble the docker-compose.yml file
	@docker run -it --rm -v $(PWD):/${DOCKER_IMAGE_NAME} \
		-u $(shell id -u):$(shell id -g) \
		itisfoundation/ci-service-integration-library:v1.0.1-dev-33 \
		sh -c "cd /${DOCKER_IMAGE_NAME} && ooil compose"

clean:
	rm -rf docker-compose.yml

.PHONY: build
build: clean compose-spec	## build docker image
	docker-compose build

clean-validation:
	sudo rm -rf validation-tmp
	cp -r validation validation-tmp
	chmod -R 770 validation-tmp

run-compose-local: clean-validation
	docker-compose --file docker-compose-local.yml up

run-mock-mapservice: clean-validation
	pip install osparc-filecomms
	MOCK_MAP_INPUT_PATH=validation-tmp/outputs/output_1 MOCK_MAP_OUTPUT_PATH=validation-tmp/inputs/input_1 python validation-client/mock_mapservice.py

run-validation-client: clean-validation
	pip install osparc-filecomms
	VALIDATION_CLIENT_INPUT_PATH=validation-tmp/outputs/output_0 VALIDATION_CLIENT_OUTPUT_PATH=validation-tmp/inputs/input_0 python validation-client/client.py

.PHONY: run-local
run-local: clean-validation run-compose-local run-mock-mapservice run-validation-client

.PHONY: publish-local
publish-local: ## push to local throw away registry to test integration
	docker tag simcore/services/dynamic/${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} registry:5000/simcore/services/dynamic/$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)
	docker push registry:5000/simcore/services/dynamic/$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)
	@curl registry:5000/v2/_catalog | jq

.PHONY: help
help: ## this colorful help
	@echo "Recipes for '$(notdir $(CURDIR))':"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[[:alpha:][:space:]_-]+:.*?## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
