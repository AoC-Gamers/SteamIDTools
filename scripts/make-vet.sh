#!/usr/bin/env bash
set -euo pipefail

project_dir="${1:-go}"
project_dir_abs="$(cd "$project_dir" && pwd)"

echo "Ejecutando go vet..."
(
  cd "$project_dir_abs"
  go vet ./...
)

