# SteamIDTools

Servicio HTTP y toolkit para conversion de SteamID, con backend Go y soporte de integracion para SourceMod.

## Componentes

- Backend Go para conversiones `SteamID64`, `AccountID`, `SteamID2` y `SteamID3`
- OpenAPI/Swagger para exploracion de la API
- Include SourceMod para conversiones offline
- Plugin SourceMod con transporte HTTP por `SteamWorks` y `system2`

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

- [Changelog General](./CHANGELOG.md)
- [Changelog Backend Go](./go/CHANGELOG.md)
- [Changelog SourceMod](./sourcemod/CHANGELOG.md)
- Tags de release: `backend/vX.Y.Z` y `sourcemod/vX.Y.Z`

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
