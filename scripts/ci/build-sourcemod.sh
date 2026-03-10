#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="${RUNNER_TEMP:-$ROOT_DIR/.tmp}/sourcemod-build"
DIST_DIR="$ROOT_DIR/dist/sourcemod"
SOURCEMOD_ARCHIVE_URL="${SOURCEMOD_ARCHIVE_URL:?SOURCEMOD_ARCHIVE_URL is required}"

rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$DIST_DIR"

echo "Downloading SourceMod compiler package..."
curl -fsSL "$SOURCEMOD_ARCHIVE_URL" -o "$WORK_DIR/sourcemod.tar.gz"
tar -xzf "$WORK_DIR/sourcemod.tar.gz" -C "$WORK_DIR"

SOURCEMOD_DIR="$WORK_DIR"
SPCOMP_BIN="$SOURCEMOD_DIR/addons/sourcemod/scripting/spcomp"
PACKAGE_DIR="$WORK_DIR/package"
PACKAGE_SM_DIR="$PACKAGE_DIR/sourcemod"

echo "Compiling steamidtools.sp..."
"$SPCOMP_BIN" \
  "$ROOT_DIR/sourcemod/scripting/steamidtools.sp" \
  -i"$ROOT_DIR/sourcemod/scripting/include" \
  -o"$DIST_DIR/steamidtools.smx" \
  2>&1 | tee "$DIST_DIR/compile.log"

if [[ ! -f "$DIST_DIR/steamidtools.smx" ]]; then
  echo "Compiled plugin was not generated." >&2
  exit 1
fi

mkdir -p "$PACKAGE_SM_DIR/plugins"
mkdir -p "$PACKAGE_SM_DIR/scripting/include/system2"

cp -R "$ROOT_DIR/sourcemod/scripting" "$PACKAGE_SM_DIR/"
cp "$DIST_DIR/steamidtools.smx" "$PACKAGE_SM_DIR/plugins/steamidtools.smx"
rm -f "$PACKAGE_SM_DIR/scripting/include/SteamWorks.inc"
rm -f "$PACKAGE_SM_DIR/scripting/include/system2.inc"
rm -rf "$PACKAGE_SM_DIR/scripting/include/system2"

(
  cd "$PACKAGE_DIR"
  if command -v zip >/dev/null 2>&1; then
    zip -rq "$DIST_DIR/steamidtools-package.zip" sourcemod
  else
    python3 -m zipfile -c "$DIST_DIR/steamidtools-package.zip" sourcemod
  fi
)

echo "SourceMod artifacts generated in $DIST_DIR"
