#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG_NAME="${1:-${GITHUB_REF_NAME:-}}"

if [[ -z "$TAG_NAME" ]]; then
  echo "Release tag is required." >&2
  exit 1
fi

case "$TAG_NAME" in
  backend/v*)
    component="backend"
    version="${TAG_NAME#backend/v}"
    expected_version="$(sed -n 's/^const Version = "\(.*\)"$/\1/p' "$ROOT_DIR/go/internal/app/version.go" | head -n 1)"
    release_name="Backend v${version}"
    ;;
  sourcemod/v*)
    component="sourcemod"
    version="${TAG_NAME#sourcemod/v}"
    expected_version="$(sed -n 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$ROOT_DIR/sourcemod/scripting/steamidtools.sp" | head -n 1)"
    release_name="SourceMod v${version}"
    ;;
  *)
    echo "Unsupported release tag '$TAG_NAME'. Use backend/vX.Y.Z or sourcemod/vX.Y.Z." >&2
    exit 1
    ;;
esac

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]]; then
  echo "Tag version '$version' is not valid SemVer." >&2
  exit 1
fi

if [[ -z "$expected_version" ]]; then
  echo "Could not resolve expected version for component '$component'." >&2
  exit 1
fi

if [[ "$version" != "$expected_version" ]]; then
  echo "Tag version '$version' does not match declared $component version '$expected_version'." >&2
  exit 1
fi

prerelease="false"
if [[ "$version" == *-* ]]; then
  prerelease="true"
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "component=$component"
    echo "version=$version"
    echo "release_name=$release_name"
    echo "prerelease=$prerelease"
  } >> "$GITHUB_OUTPUT"
else
  cat <<EOF
component=$component
version=$version
release_name=$release_name
prerelease=$prerelease
EOF
fi
