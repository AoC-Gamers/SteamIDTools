SHELL := /bin/bash

.PHONY: help deps go-tools fmt vet lint gosec nancy swagger test build clean

REPORTS_DIR := reports
SCRIPTS_DIR := scripts
GO_DIR := go

GOLANGCI_LINT_VERSION ?= 2.4.0
GOSEC_VERSION ?= 2.23.0
NANCY_VERSION ?= v1.2.0
SWAG_VERSION ?= v1.16.6

help: ## Mostrar comandos disponibles
	@echo "SteamIDTools - Comandos de desarrollo"
	@echo "===================================="
	@echo "  go-tools instala golangci-lint, gosec y nancy en versiones definidas"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-12s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

deps: ## Descargar y ordenar dependencias
	@bash $(SCRIPTS_DIR)/make-deps.sh "$(GO_DIR)"

go-tools: ## Instalar herramientas de CI/desarrollo
	@bash $(SCRIPTS_DIR)/make-go-tools.sh "$(GOLANGCI_LINT_VERSION)" "$(GOSEC_VERSION)" "$(NANCY_VERSION)"

fmt: ## Formatear codigo
	@bash $(SCRIPTS_DIR)/make-fmt.sh "$(GO_DIR)"

vet: ## Ejecutar go vet
	@bash $(SCRIPTS_DIR)/make-vet.sh "$(GO_DIR)"

lint: ## Ejecutar golangci-lint
	@bash $(SCRIPTS_DIR)/make-lint.sh "$(GO_DIR)" "$(REPORTS_DIR)" "$(GOLANGCI_LINT_VERSION)"

gosec: ## Ejecutar escaneo de seguridad con gosec
	@bash $(SCRIPTS_DIR)/make-gosec.sh "$(GO_DIR)" "$(REPORTS_DIR)" "$(GOSEC_VERSION)"

nancy: ## Ejecutar escaneo de dependencias con Nancy
	@bash $(SCRIPTS_DIR)/make-nancy.sh "$(GO_DIR)" "$(NANCY_VERSION)"

swagger: ## Generar documentacion Swagger
	@bash $(SCRIPTS_DIR)/make-swagger.sh "$(GO_DIR)" "$(SWAG_VERSION)"

test: ## Ejecutar tests
	@bash $(SCRIPTS_DIR)/make-test.sh "$(GO_DIR)"

build: ## Compilar binario del backend
	@bash $(SCRIPTS_DIR)/make-build-bin.sh "$(GO_DIR)" "$(GO_DIR)/bin" "steamid-service"

clean: ## Limpiar cache de Go y artefactos de build
	@bash $(SCRIPTS_DIR)/make-clean.sh "$(GO_DIR)" "$(REPORTS_DIR)" "dist"
