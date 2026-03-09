# Inicio Rapido

## Requisitos

### Ejecucion directa

- Go 1.26 o superior

### Docker

- Docker 20.10 o superior
- Docker Compose v2

## Opcion 1: Docker Compose

### Desarrollo

Usa `docker-compose.dev.yml` cuando quieras construir localmente desde el codigo fuente.

```bash
docker compose -f docker-compose.dev.yml up -d --build
```

### Produccion

Usa `docker-compose.yml` cuando quieras correr la imagen publicada.

```bash
docker compose -f docker-compose.yml up -d
```

## Opcion 2: Ejecucion directa

```bash
cd go
go run ./cmd/steamid-service
```

Prueba rapida:

```bash
curl "http://localhost:80/SID64toAID?steamid=76561197960287930"
curl "http://localhost:80/health"
```

## Swagger

UI interactiva:

```text
http://localhost:80/swagger/index.html
```

Regenerar artefactos OpenAPI:

```bash
make swagger
```

## Makefile

Targets disponibles:

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

## Logs

El backend emite logs JSON con `zerolog` a `stdout/stderr`.

```bash
docker compose -f docker-compose.dev.yml logs -f steamid-service
docker compose -f docker-compose.yml logs -f steamid-service
docker logs -f steamid-service
```
