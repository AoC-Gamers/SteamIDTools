# SPDX-License-Identifier: GPL-3.0-or-later

PYTHON ?= python3
SMX_PLATFORM ?= linux
SOURCEMOD_VERSION ?= 1.12
STOCK_INCLUDE ?= addons/sourcemod/scripting/include/steamidtools.inc
PROJECT_DIR := $(shell dirname -- "$(MAKEFILE_LIST)")

.PHONY: help deps-smx deps-test test test-offline test-modules build-test-server clean

help:
	@printf '%s\n' 'make deps-test          Preparar compilador y VM (Linux x86_64)' \
		'make test               Ejecutar las pruebas de conversiones, imports y módulos' \
		'make build-test-server  Compilar el harness opcional para SRCDS' \
		'make clean              Eliminar las salidas locales de prueba'

deps-smx:
	cd "$(PROJECT_DIR)" && $(PYTHON) scripts/deps/fetch-sourcemod.py --platform "$(SMX_PLATFORM)" --version "$(SOURCEMOD_VERSION)"

deps-test: deps-smx
	cd "$(PROJECT_DIR)" && $(PYTHON) tests/runners/test-sourcepawn-offline.py --prepare-vm

test: test-offline test-modules

test-offline:
	cd "$(PROJECT_DIR)" && $(PYTHON) tests/runners/test-sourcepawn-offline.py --stock-include "$(STOCK_INCLUDE)"

test-modules:
	cd "$(PROJECT_DIR)" && $(PYTHON) -m unittest discover -s tests/python -v

build-test-server:
	cd "$(PROJECT_DIR)" && $(PYTHON) tests/runners/test-sourcepawn-offline.py --server-plugin --stock-include "$(STOCK_INCLUDE)"

clean:
	cd "$(PROJECT_DIR)" && rm -rf .build
