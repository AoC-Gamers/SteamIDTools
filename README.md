# SteamIDTools

Servicio HTTP y toolkit para conversion de SteamID, con backend Go y soporte de integracion para SourceMod.

## Componentes

- Backend Go para conversiones `SteamID64`, `AccountID`, `SteamID2` y `SteamID3`
- OpenAPI/Swagger para exploracion de la API
- Include SourceMod para conversiones offline
- Plugin API SourceMod para conversiones online via backend con `SteamWorks` o `system2`
- Plugin demo SourceMod para probar la API y las conversiones offline

## Inicio Rapido

### Docker Compose

Desarrollo:

```bash
docker compose -f docker-compose.dev.yml up -d --build
```

Produccion:

```bash
docker compose -f docker-compose.yml up -d
```

### Ejecucion directa

```bash
cd go
go run ./cmd/steamid-service
```

### Verificacion

```bash
curl "http://localhost:80/health"
```

Swagger UI:

```text
http://localhost:80/swagger/index.html
```

## Documentacion

- [Indice de documentacion](./docs/README.md)
- [Inicio Rapido](./docs/getting-started.md)
- [API HTTP](./docs/api.md)
- [Despliegue y Operacion](./docs/deployment.md)
- [Integracion SourceMod](./docs/sourcemod.md)
- [Arquitectura](./docs/architecture.md)

## Changelog y Versionado

- [Changelog Backend Go](./go/CHANGELOG.md)
- [Changelog SourceMod](./sourcemod/CHANGELOG.md)

Este repositorio usa versionado diferenciado por componente:

- Backend Go: versionado independiente con SemVer
- Plugin/Include SourceMod: versionado independiente con SemVer
- API HTTP: compatibilidad logica versionada por major

Compatibilidad:

| HTTP API | Backend Go | SourceMod Plugin |
|----------|------------|------------------|
| v1 | 2.x | 2.x |

Reglas:

- Incrementa `patch` cuando hay fixes, logging, tests, documentacion o mejoras internas sin cambio compatible-visible
- Incrementa `minor` cuando agregas funcionalidad compatible
- Incrementa `major` cuando rompes compatibilidad del componente
- Si rompes el contrato HTTP, incrementa el `major` de la API y documenta la compatibilidad minima entre backend y plugin
- Backend y SourceMod no necesitan publicar la misma version salvo que quieras alinear releases por conveniencia

Tags de release:

- Backend Go: `backend/vX.Y.Z`
- SourceMod Plugin/Include: `sourcemod/vX.Y.Z`
- Los tags deben coincidir con la version declarada en el componente antes de publicar el release

## Tooling

```bash
make deps
make fmt
make swagger
make test
make lint
make gosec
make build
make clean
```
