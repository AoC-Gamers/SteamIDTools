#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/dist/release"
BACKEND_BINARY="${BACKEND_BINARY:-$ROOT_DIR/go/bin/steamid-service}"
SOURCEMOD_ARTIFACT_DIR="${SOURCEMOD_ARTIFACT_DIR:-$ROOT_DIR/dist/sourcemod/artifact}"

if [[ ! -f "$BACKEND_BINARY" ]]; then
  echo "Backend binary not found at $BACKEND_BINARY" >&2
  exit 1
fi

if [[ ! -d "$SOURCEMOD_ARTIFACT_DIR" ]]; then
  echo "SourceMod artifact directory not found at $SOURCEMOD_ARTIFACT_DIR" >&2
  exit 1
fi

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

cp "$BACKEND_BINARY" "$RELEASE_DIR/steamid-service-linux-amd64"
(
  cd "$RELEASE_DIR"
  tar -czf steamid-service-linux-amd64.tar.gz steamid-service-linux-amd64
)

python3 - "$SOURCEMOD_ARTIFACT_DIR" "$RELEASE_DIR/steamidtools-sourcemod-release.zip" <<'PY'
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

(
  cd "$RELEASE_DIR"
  sha256sum \
    steamid-service-linux-amd64.tar.gz \
    steamidtools-sourcemod-release.zip \
    > sha256sums.txt
)

echo "Release assets generated in $RELEASE_DIR"
