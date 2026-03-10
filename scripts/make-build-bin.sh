#!/usr/bin/env bash
set -euo pipefail

project_dir="${1:-go}"
output_dir="${2:-go/bin}"
binary_name="${3:-steamid-service}"
package_path="${4:-./cmd/steamid-service}"

project_dir_abs="$(cd "$project_dir" && pwd)"
repo_root="$(cd "$project_dir_abs/.." && pwd)"
output_dir_abs="$repo_root/$output_dir"
goexe="$(cd "$project_dir_abs" && go env GOEXE)"
binary_path="$output_dir_abs/$binary_name$goexe"

echo "Compilando ${binary_name}${goexe} ..."
mkdir -p "$output_dir_abs"

(
  cd "$project_dir_abs"
  go build -o "$binary_path" "$package_path"
)

echo "Binario generado en ${binary_path}"
