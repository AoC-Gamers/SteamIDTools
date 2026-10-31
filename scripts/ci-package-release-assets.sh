#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
make package-smx release-smx SMX_RELEASE_BASENAME="steamidtools-sourcemod-${RELEASE_VERSION:-local}"
(cd dist/release && sha256sum "steamidtools-sourcemod-${RELEASE_VERSION:-local}.zip" > sha256sums.txt)
