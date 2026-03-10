#!/usr/bin/env bash
set -euo pipefail

project_dir="${1:-go}"
reports_dir="${2:-reports}"
golangci_lint_version="${3:-2.4.0}"

project_dir_abs="$(cd "$project_dir" && pwd)"
repo_root="$(cd "$project_dir_abs/.." && pwd)"
reports_dir_abs="$repo_root/$reports_dir"
gopath_bin="$(go env GOPATH)/bin"
lint_bin=""

echo "Ejecutando golangci-lint..."
for candidate in "$gopath_bin/golangci-lint" "$gopath_bin/golangci-lint.exe" "$(command -v golangci-lint 2>/dev/null || true)"; do
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    lint_bin="$candidate"
    break
  fi
done

[[ -n "$lint_bin" ]] || {
  echo "Error: golangci-lint no esta instalado. Instalalo con la version ${golangci_lint_version}."
  exit 1
}

installed="$("$lint_bin" version 2>/dev/null | head -n1)"
required="${golangci_lint_version#v}"
installed_version="$(echo "$installed" | sed -nE 's/.*version[[:space:]]+v?([0-9]+(\.[0-9]+){1,2}).*/\1/p' | head -n1)"

[ -n "$installed_version" ] || {
  echo "Error: no se pudo detectar la version instalada de golangci-lint."
  exit 1
}

case "$installed_version" in
  "$required"|"$required".*) ;;
  *)
    echo "Error: se requiere golangci-lint ${required}.x (instalada ${installed_version})."
    exit 1
    ;;
esac

required_go="$(sed -nE 's/^go[[:space:]]+([0-9]+(\.[0-9]+){1,2}).*/\1/p' "$project_dir_abs/go.mod" | head -n1)"
[ -n "$required_go" ] || {
  echo "Error: no se pudo leer la version de Go requerida desde go.mod."
  exit 1
}

echo "$installed" | grep -q "built with go${required_go}" || {
  echo "Error: se requiere golangci-lint compilado con go${required_go}."
  exit 1
}

mkdir -p "$reports_dir_abs"
(
  cd "$project_dir_abs"
  if "$lint_bin" run --help 2>&1 | grep -q -- "--output.json.path"; then
    "$lint_bin" run --timeout=5m --output.json.path "${reports_dir_abs}/lint.json"
  else
    "$lint_bin" run --timeout=5m --out-format json > "${reports_dir_abs}/lint.json"
  fi
)

echo "Reporte JSON generado en ${reports_dir_abs}/lint.json"
