#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/dist/release"
RELEASE_COMPONENT="${RELEASE_COMPONENT:-all}"
BACKEND_BINARY="${BACKEND_BINARY:-$ROOT_DIR/go/bin/steamid-service}"
SOURCEMOD_ARTIFACT_DIR="${SOURCEMOD_ARTIFACT_DIR:-$ROOT_DIR/dist/sourcemod/artifact}"
RELEASE_VERSION="${RELEASE_VERSION:-latest}"

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

artifacts=()

if [[ "$RELEASE_COMPONENT" == "backend" || "$RELEASE_COMPONENT" == "all" ]]; then
  if [[ ! -f "$BACKEND_BINARY" ]]; then
    echo "Backend binary not found at $BACKEND_BINARY" >&2
    exit 1
  fi

  backend_asset_base="steamid-service-linux-amd64-${RELEASE_VERSION}"
  cp "$BACKEND_BINARY" "$RELEASE_DIR/$backend_asset_base"
  (
    cd "$RELEASE_DIR"
    tar -czf "${backend_asset_base}.tar.gz" "$backend_asset_base"
  )
  rm -f "$RELEASE_DIR/$backend_asset_base"
  artifacts+=("${backend_asset_base}.tar.gz")
fi

if [[ "$RELEASE_COMPONENT" == "sourcemod" || "$RELEASE_COMPONENT" == "all" ]]; then
  if [[ ! -d "$SOURCEMOD_ARTIFACT_DIR" ]]; then
    echo "SourceMod artifact directory not found at $SOURCEMOD_ARTIFACT_DIR" >&2
    exit 1
  fi

  make release-smx PYTHON=python3 SMX_RELEASE_BASENAME="steamidtools-sourcemod-${RELEASE_VERSION}"
  artifacts+=("steamidtools-sourcemod-${RELEASE_VERSION}.zip")
fi

if [[ ${#artifacts[@]} -eq 0 ]]; then
  echo "Unsupported release component '$RELEASE_COMPONENT'." >&2
  exit 1
fi

(
  cd "$RELEASE_DIR"
  sha256sum "${artifacts[@]}" > sha256sums.txt
)

echo "Release assets generated in $RELEASE_DIR"
