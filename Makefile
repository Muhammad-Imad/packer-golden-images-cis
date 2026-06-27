# =============================================================================
# packer-golden-images-cis — Makefile
# Convenience wrappers over the Packer CLI. Override VAR_FILE / PROFILE / ONLY
# on the command line, e.g.:
#   make build ONLY=amazon-ebs.ubuntu VAR_FILE=prod.pkrvars.hcl
# =============================================================================

PACKER   ?= packer
VAR_FILE ?= example.pkrvars.hcl
ONLY     ?=
TEMPLATE ?= .

VAR_ARG  := $(if $(wildcard $(VAR_FILE)),-var-file=$(VAR_FILE),)
ONLY_ARG := $(if $(ONLY),-only=$(ONLY),)

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

.PHONY: init
init: ## Install required Packer plugins
	$(PACKER) init $(TEMPLATE)

.PHONY: fmt
fmt: ## Format all HCL templates in place
	$(PACKER) fmt -recursive $(TEMPLATE)

.PHONY: fmt-check
fmt-check: ## Check HCL formatting without modifying files (CI)
	$(PACKER) fmt -check -recursive $(TEMPLATE)

.PHONY: validate
validate: init ## Validate templates against the var-file
	$(PACKER) validate $(VAR_ARG) $(ONLY_ARG) $(TEMPLATE)

.PHONY: build
build: validate ## Build AMIs (set ONLY= to target one source/build)
	$(PACKER) build -timestamp-ui $(VAR_ARG) $(ONLY_ARG) $(TEMPLATE)

.PHONY: ubuntu rhel amazon-linux windows
ubuntu: ## Build only the Ubuntu 24.04 image
	$(MAKE) build ONLY=amazon-ebs.ubuntu

rhel: ## Build only the RHEL 9 image
	$(MAKE) build ONLY=amazon-ebs.rhel

amazon-linux: ## Build only the Amazon Linux 2023 image
	$(MAKE) build ONLY=amazon-ebs.amazon_linux

windows: ## Build both Windows Server images
	$(MAKE) build ONLY=windows.*

.PHONY: clean
clean: ## Remove generated manifests
	rm -f manifests/*-manifest.json
