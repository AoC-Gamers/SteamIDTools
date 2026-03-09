# Changelog

Este repositorio usa versionado diferenciado por componente:

- Backend Go: versionado independiente con SemVer.
- Plugin/Include SourceMod: versionado independiente con SemVer.
- API HTTP: compatibilidad lógica versionada por major.

## Current Versions

| Component | Version |
|-----------|---------|
| Backend Go | 2.0.0 |
| SourceMod Plugin | 2.0.0 |
| HTTP API | v1 |

## Compatibility

| HTTP API | Backend Go | SourceMod Plugin |
|----------|------------|------------------|
| v1 | 2.x | 2.x |

## Versioning Policy

- Incrementa `patch` cuando hay fixes, logging, tests, documentación o mejoras internas sin cambio compatible-visible.
- Incrementa `minor` cuando agregas funcionalidad compatible.
- Incrementa `major` cuando rompes compatibilidad del componente.
- Si rompes el contrato HTTP, incrementa el `major` de la API y documenta la compatibilidad mínima entre backend y plugin.
- Backend y SourceMod no necesitan publicar la misma versión salvo que quieras alinear releases por conveniencia.

## Component Changelogs

- [Backend Go](./go/CHANGELOG.md)
- [SourceMod](./sourcemod/CHANGELOG.md)
