#!/usr/bin/env bash
set -euo pipefail

project_dir="${1:-go}"
reports_dir="${2:-reports}"
gosec_version="${3:-2.23.0}"

project_dir_abs="$(cd "$project_dir" && pwd)"
repo_root="$(cd "$project_dir_abs/.." && pwd)"
reports_dir_abs="$repo_root/$reports_dir"
gopath_bin="$(go env GOPATH)/bin"
gosec_bin=""

echo "Ejecutando escaneo de seguridad con gosec..."
for candidate in "$gopath_bin/gosec" "$gopath_bin/gosec.exe" "$(command -v gosec 2>/dev/null || true)"; do
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    gosec_bin="$candidate"
    break
  fi
done

[[ -n "$gosec_bin" ]] || {
  echo "Error: gosec no esta instalado. Instalalo con la version ${gosec_version}."
  exit 1
}

mkdir -p "$reports_dir_abs"
rc=0
(
  cd "$project_dir_abs"
  "$gosec_bin" -fmt=json -out="${reports_dir_abs}/gosec.json" ./cmd/steamid-service/... ./internal/app/...
) || rc=$?

echo "Reporte JSON generado en ${reports_dir_abs}/gosec.json"

if command -v jq >/dev/null 2>&1; then
  found="$(jq -r '.Stats.found // 0' "${reports_dir_abs}/gosec.json")"
  files="$(jq -r '.Stats.files // 0' "${reports_dir_abs}/gosec.json")"
  nosec="$(jq -r '.Stats.nosec // 0' "${reports_dir_abs}/gosec.json")"
  printf "Resumen gosec: found=%s files=%s nosec=%s\n" "$found" "$files" "$nosec"
else
  found="$(grep -o '"rule_id"' "${reports_dir_abs}/gosec.json" | wc -l | tr -d '[:space:]')"
  printf "Resumen gosec: found=%s (instala jq para ver mas detalle)\n" "$found"
fi

if [ "$rc" -ne 0 ]; then
  echo "gosec finalizo con errores (exit ${rc}). Revisa ${reports_dir_abs}/gosec.json"
  exit "$rc"
fi
