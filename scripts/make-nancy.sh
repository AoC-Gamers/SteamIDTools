#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${1:-go}"
NANCY_VERSION="${2:-v1.2.0}"
OSSINDEX_USERNAME="${OSSINDEX_USERNAME:-}"
OSSINDEX_TOKEN="${OSSINDEX_TOKEN:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_DIR_ABS="$(cd "${PROJECT_DIR}" && pwd)"
SECRETS_FILE="${ROOT_DIR}/.env.secrets"
EXPECTED_NANCY_VERSION="${NANCY_VERSION#v}"

export PATH="$(go env GOPATH)/bin:${PATH}"

NANCY_BIN="$(command -v "$(go env GOPATH)/bin/nancy" 2>/dev/null || command -v "$(go env GOPATH)/bin/nancy.exe" 2>/dev/null || command -v nancy || command -v nancy.exe || true)"
if [[ -z "${NANCY_BIN}" ]]; then
  echo "nancy no esta instalado. Instálalo primero y vuelve a ejecutar 'make nancy'."
  exit 1
fi

RAW_NANCY_VERSION="$("${NANCY_BIN}" -V 2>/dev/null || "${NANCY_BIN}" --version 2>/dev/null || true)"
INSTALLED_NANCY_VERSION="$(echo "${RAW_NANCY_VERSION}" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)"

if [[ -z "${INSTALLED_NANCY_VERSION}" ]]; then
  echo "No se pudo determinar la version de Nancy instalada."
  echo "Salida recibida: ${RAW_NANCY_VERSION}"
  exit 1
fi

if [[ "${INSTALLED_NANCY_VERSION}" != "${EXPECTED_NANCY_VERSION}" ]]; then
  echo "Version de Nancy invalida. Requerida: ${EXPECTED_NANCY_VERSION}. Instalada: ${INSTALLED_NANCY_VERSION}."
  exit 1
fi

if [[ ( -z "${OSSINDEX_USERNAME}" || -z "${OSSINDEX_TOKEN}" ) && -f "${SECRETS_FILE}" ]]; then
  echo "Cargando credenciales OSS Index desde .env.secrets..."
  set -a
  # shellcheck disable=SC1090
  source "${SECRETS_FILE}"
  set +a
  OSSINDEX_USERNAME="${OSSINDEX_USERNAME:-}"
  OSSINDEX_TOKEN="${OSSINDEX_TOKEN:-}"
fi

if [[ -z "${OSSINDEX_USERNAME}" || -z "${OSSINDEX_TOKEN}" ]]; then
  echo "OSSINDEX_USERNAME/OSSINDEX_TOKEN no estan configurados. Se omite Nancy para evitar errores OSS Index 401."
  exit 0
fi

echo "Ejecutando Nancy (OSS Index autenticado)..."
(
  cd "${PROJECT_DIR_ABS}"
  go list -json -deps ./... | "${NANCY_BIN}" sleuth \
    --skip-update-check \
    --username "${OSSINDEX_USERNAME}" \
    --token "${OSSINDEX_TOKEN}"
)
