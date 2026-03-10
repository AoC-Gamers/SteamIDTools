#!/usr/bin/env bash
set -euo pipefail

project_dir="${1:-go}"
swag_version="${2:-v1.16.6}"
project_dir_abs="$(cd "$project_dir" && pwd)"
swag_clean_version="${swag_version#v}"

echo "Generando Swagger..."
(
  cd "$project_dir_abs"
  go run "github.com/swaggo/swag/cmd/swag@v${swag_clean_version}" init \
    -g main.go \
    -d ./cmd/steamid-service,./internal/app \
    -o ./internal/app/docs \
    --parseInternal
)

