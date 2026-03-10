#!/usr/bin/env bash
set -euo pipefail

golangci_lint_version="${1:-2.4.0}"
gosec_version="${2:-2.23.0}"
nancy_version="${3-v1.2.0}"

lint_version="${golangci_lint_version#v}"
gosec_clean_version="${gosec_version#v}"

echo "Instalando herramientas de desarrollo..."
go install "github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v${lint_version}"
go install "github.com/securego/gosec/v2/cmd/gosec@v${gosec_clean_version}"

if [[ -n "${nancy_version}" ]]; then
  nancy_clean_version="${nancy_version#v}"
  go install "github.com/sonatype-nexus-community/nancy@v${nancy_clean_version}"
  echo "Herramientas instaladas: golangci-lint v${lint_version}, gosec v${gosec_clean_version}, nancy v${nancy_clean_version}"
else
  echo "Herramientas instaladas: golangci-lint v${lint_version}, gosec v${gosec_clean_version}"
fi
