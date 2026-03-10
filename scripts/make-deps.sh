#!/usr/bin/env bash
set -euo pipefail

project_dir="${1:-go}"
project_dir_abs="$(cd "$project_dir" && pwd)"

echo "Actualizando dependencias..."
(
  cd "$project_dir_abs"
  go mod download
  go mod tidy
  go mod verify
)

