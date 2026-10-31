SHELL := /bin/bash
PYTHON ?= python3
SMX_PLATFORM ?= linux
SOURCEMOD_VERSION ?= 1.12
SMX_BUILD_DIR ?= .build/smx
SMX_PACKAGE_DIR ?= .build/package-smx
SMX_RELEASE_BASENAME ?= steamidtools-sourcemod-local
.PHONY: deps-smx build-smx test-offline check-package package-smx release-smx clean

deps-smx: ## Preparar el compilador y los includes de SourceMod
	$(PYTHON) ./scripts/fetch-sourcemod.py --root . --platform "$(SMX_PLATFORM)" --version "$(SOURCEMOD_VERSION)"

build-smx: ## Preparar los includes del toolkit offline
	$(PYTHON) ./scripts/build-local.py --root . --output-root "$(SMX_BUILD_DIR)" --build-log deps/build-toolkit.log

test-offline: ## Probar stocks reales en SourcePawn VM (requiere preparacion; Linux x86_64)
	$(PYTHON) ./scripts/test-sourcepawn-offline.py

package-smx: ## Preparar arbol SourceMod para artifact/release
	$(PYTHON) ./scripts/stage-artifact.py . "$(SMX_BUILD_DIR)" "deps/build-toolkit.log" "$(SMX_PACKAGE_DIR)"

release-smx: ## Generar ZIP SourceMod desde el arbol empaquetado
	$(PYTHON) ./scripts/stage-artifact.py . "$(SMX_PACKAGE_DIR)" "deps/build-toolkit.log"
	$(PYTHON) ./scripts/package-release.py --root . --basename "$(SMX_RELEASE_BASENAME)"

check-package:
	$(PYTHON) -m unittest discover -s tests/python -v

clean:
	$(PYTHON) -c "import shutil; [shutil.rmtree(p, ignore_errors=True) for p in ['.build', 'dist']]"
