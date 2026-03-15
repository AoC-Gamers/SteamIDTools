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

  sourcemod_asset="steamidtools-sourcemod-${RELEASE_VERSION}.zip"

  python3 - "$SOURCEMOD_ARTIFACT_DIR" "$RELEASE_DIR/$sourcemod_asset" <<'PY'
import os
import sys
import zipfile

src_dir, out_file = sys.argv[1], sys.argv[2]

with zipfile.ZipFile(out_file, "w", zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk(src_dir):
        dirs.sort()
        files.sort()
        rel_root = os.path.relpath(root, src_dir)
        if rel_root != "." and not dirs and not files:
            zf.writestr(rel_root.rstrip("/") + "/", "")
        for name in files:
            path = os.path.join(root, name)
            arcname = os.path.relpath(path, src_dir)
            zf.write(path, arcname)
PY
  artifacts+=("$sourcemod_asset")
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
