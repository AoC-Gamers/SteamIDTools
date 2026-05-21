# Sistema de Build

## Objetivo

Este repositorio es mixto:

- backend Go
- componente SourceMod

El flujo homologado se aplica solo al carril SourceMod, sin interferir con las tareas del backend.

## Carril SourceMod

Archivos principales:

- `plugin-package-map.json`
- `scripts/fetch-sourcemod.py`
- `scripts/build-local.py`
- `scripts/stage-artifact.py`
- `scripts/package-release.py`
- `scripts/ci-build-sourcemod.sh`
- `scripts/ci-validate-artifact.sh`
- `.github/workflows/sourcemod-build.yml`

Targets:

- `make deps-smx`
- `make build-smx`
- `make package-smx`
- `make release-smx`

## Manifiesto

`plugin-package-map.json` define:

- `build.plugins`
- `artifact.sourcemod`

En este repo:

- se compila solo `steamidtools.sp`
- el binario se publica en `addons/sourcemod/plugins/custom/`
- el artifact incluye:
  - `scripting/steamidtools.sp`
  - `scripting/steamidtools/`
  - includes publicas:
    - `steamidtools.inc`
    - `steamidtools_helpers.inc`
    - `steamidtools_stock.inc`

Se excluyen explicitamente del bundle publico:

- `steamidtools_test.sp`
- `steamworks.inc`
- `system2.inc`
- `include/system2/`

## CI

El workflow SourceMod usa:

- `deps-smx`
- `build-smx`
- `release-smx`

El workflow de releases del repo sigue siendo mixto, pero el asset SourceMod ya usa el mismo flujo homologado antes de empaquetarse.

## WSL

Si el repo vive bajo `/mnt/`, `build-local.py` usa automaticamente un workspace temporal Linux para evitar la penalizacion de I/O de WSL sobre discos montados.
