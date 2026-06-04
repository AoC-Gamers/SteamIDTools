SHELL := /bin/bash

.PHONY: help deps go-tools fmt vet lint gosec nancy swagger test build deps-smx build-smx package-smx release-smx clean clean-all

REPORTS_DIR := reports
SCRIPTS_DIR := scripts
GO_DIR := go
SMX_DIR := sourcemod

ifeq ($(OS),Windows_NT)
PYTHON ?= python
SMX_PLATFORM ?= windows
SPCOMP ?= deps/sourcemod-windows/addons/sourcemod/scripting/spcomp.exe
else
PYTHON ?= $(shell command -v python3 >/dev/null 2>&1 && echo python3 || echo python)
SMX_PLATFORM ?= linux
SPCOMP ?= deps/sourcemod-linux/addons/sourcemod/scripting/spcomp
endif

SOURCEMOD_VERSION ?= 1.12
SMX_BUILD_DIR ?= .build/smx
SMX_PACKAGE_DIR ?= .build/package-smx
SMX_RELEASE_BASENAME ?= steamidtools-sourcemod-local

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

deps-smx: ## Descargar dependencias de SourceMod para compilar el plugin
	$(PYTHON) ./scripts/fetch-sourcemod.py --root . --platform "$(SMX_PLATFORM)" --version "$(SOURCEMOD_VERSION)"

build-smx: ## Compilar plugin SourceMod
	$(PYTHON) ./scripts/build-local.py --root . --spcomp "$(SPCOMP)" --output-root "$(SMX_BUILD_DIR)" --compile-log deps/build-smx-compile.log

package-smx: ## Preparar arbol SourceMod para artifact/release
	$(PYTHON) ./scripts/stage-artifact.py . "$(SMX_BUILD_DIR)" "deps/build-smx-compile.log" "$(SMX_PACKAGE_DIR)"

release-smx: ## Generar ZIP SourceMod desde el arbol empaquetado
	$(PYTHON) ./scripts/stage-artifact.py . "$(SMX_PACKAGE_DIR)" "deps/build-smx-compile.log"
	$(PYTHON) ./scripts/package-release.py --root . --basename "$(SMX_RELEASE_BASENAME)"

clean: ## Limpiar cache de Go y artefactos de build
	@bash $(SCRIPTS_DIR)/make-clean.sh "$(GO_DIR)" "$(REPORTS_DIR)" "dist"

clean-all: ## Limpiar cache de Go, deps y artefactos de build
	$(PYTHON) -c "import shutil, pathlib; [shutil.rmtree(p, ignore_errors=True) for p in map(pathlib.Path, ['.build', 'dist', 'deps'])]"
