#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${RUNNER_TEMP:-$ROOT_DIR/.tmp}/sourcemod-build"
DIST_DIR="$ROOT_DIR/dist/sourcemod"
ARTIFACT_DIR="$DIST_DIR/artifact"
SOURCEMOD_ARCHIVE_URL="${SOURCEMOD_ARCHIVE_URL:?SOURCEMOD_ARCHIVE_URL is required}"

rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$ARTIFACT_DIR"

echo "Downloading SourceMod compiler package..."
curl -fsSL "$SOURCEMOD_ARCHIVE_URL" -o "$WORK_DIR/sourcemod.tar.gz"
tar -xzf "$WORK_DIR/sourcemod.tar.gz" -C "$WORK_DIR"

SOURCEMOD_DIR="$WORK_DIR"
SPCOMP_BIN="$SOURCEMOD_DIR/addons/sourcemod/scripting/spcomp"
PACKAGE_ROOT_DIR="$ARTIFACT_DIR/addons/sourcemod"
COMPILE_LOG="$WORK_DIR/compile.log"

mkdir -p "$PACKAGE_ROOT_DIR/plugins/custom"
: > "$COMPILE_LOG"

echo "Compiling steamidtools.sp..."
"$SPCOMP_BIN" \
  "$ROOT_DIR/sourcemod/scripting/steamidtools.sp" \
  -i"$ROOT_DIR/sourcemod/scripting/include" \
  -o"$PACKAGE_ROOT_DIR/plugins/custom/steamidtools.smx" \
  2>&1 | tee -a "$COMPILE_LOG"

if [[ ! -f "$PACKAGE_ROOT_DIR/plugins/custom/steamidtools.smx" ]]; then
  echo "Compiled plugin was not generated." >&2
  exit 1
fi

mkdir -p "$PACKAGE_ROOT_DIR/scripting/include/system2"

cp -R "$ROOT_DIR/sourcemod/scripting" "$PACKAGE_ROOT_DIR/"
rm -f "$PACKAGE_ROOT_DIR/scripting/include/SteamWorks.inc"
rm -f "$PACKAGE_ROOT_DIR/scripting/include/system2.inc"
rm -rf "$PACKAGE_ROOT_DIR/scripting/include/system2"
rm -f "$PACKAGE_ROOT_DIR/scripting/steamidtools_test.sp"

if [[ ! -f "$PACKAGE_ROOT_DIR/scripting/include/steamidtools_stock.inc" ]]; then
  echo "steamidtools_stock.inc was not included in the SourceMod artifact." >&2
  exit 1
fi

echo "SourceMod artifacts generated in $ARTIFACT_DIR"
