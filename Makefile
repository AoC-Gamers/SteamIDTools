SHELL := /bin/bash
PYTHON ?= python3
SMX_PLATFORM ?= linux
SPCOMP ?= deps/sourcemod-linux/addons/sourcemod/scripting/spcomp
SOURCEMOD_VERSION ?= 1.12
SMX_BUILD_DIR ?= .build/smx
SMX_PACKAGE_DIR ?= .build/package-smx
SMX_RELEASE_BASENAME ?= steamidtools-sourcemod-local
.PHONY: deps-smx build-smx test-offline check-package package-smx release-smx clean

deps-smx: ## Descargar dependencias de SourceMod para compilar el plugin
	$(PYTHON) ./scripts/fetch-sourcemod.py --root . --platform "$(SMX_PLATFORM)" --version "$(SOURCEMOD_VERSION)"

build-smx: ## Compilar plugin SourceMod
	$(PYTHON) ./scripts/build-local.py --root . --spcomp "$(SPCOMP)" --output-root "$(SMX_BUILD_DIR)" --compile-log deps/build-smx-compile.log

test-offline: ## Probar stocks reales en SourcePawn VM (requiere preparacion; Linux x86_64)
	$(PYTHON) ./scripts/test-sourcepawn-offline.py

package-smx: ## Preparar arbol SourceMod para artifact/release
	$(PYTHON) ./scripts/stage-artifact.py . "$(SMX_BUILD_DIR)" "deps/build-smx-compile.log" "$(SMX_PACKAGE_DIR)"

release-smx: ## Generar ZIP SourceMod desde el arbol empaquetado
	$(PYTHON) ./scripts/stage-artifact.py . "$(SMX_PACKAGE_DIR)" "deps/build-smx-compile.log"
	$(PYTHON) ./scripts/package-release.py --root . --basename "$(SMX_RELEASE_BASENAME)"

check-package:
	$(PYTHON) -m unittest discover -s tests/python -v

clean:
	$(PYTHON) -c "import shutil; [shutil.rmtree(p, ignore_errors=True) for p in ['.build', 'dist']]"
