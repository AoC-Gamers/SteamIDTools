# Backend Go Changelog

Este archivo sigue el formato de Keep a Changelog y usa SemVer.

## [Unreleased]

### Added

- None.

### Changed

- None.

### Fixed

- None.

## [2.1.0]

### Added

- Swagger/OpenAPI integrado con UI servida por el backend.
- Pipelines de CI, seguridad y release para build binario e imagen Docker.

### Changed

- Backend reorganizado bajo `cmd/` e `internal/`.
- Logging estructurado con `zerolog`, idiomas embebidos y startup/access logs en JSON.
- Validaciones de conversion, batch e i18n endurecidas y consistentes.

### Fixed

- Timeouts HTTP, healthcheck de Docker y ruido de `/health` en logs.

## [2.0.0]

### Added

- Initial tracked release for the Go backend in this repository.
