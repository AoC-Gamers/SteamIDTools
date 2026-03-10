#!/usr/bin/env bash
set -euo pipefail

project_dir="${1:-go}"
reports_dir="${2:-reports}"
dist_dir="${3:-dist}"

project_dir_abs="$(cd "$project_dir" && pwd)"
repo_root="$(cd "$project_dir_abs/.." && pwd)"

echo "Limpiando..."
(
  cd "$project_dir_abs"
  go clean -cache -testcache -modcache
)

rm -rf "$project_dir_abs/bin"
rm -f "$project_dir_abs/steamid-service" "$project_dir_abs/steamid-service.exe"
rm -rf "$repo_root/$reports_dir" "$repo_root/$dist_dir"

