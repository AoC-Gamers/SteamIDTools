# Despliegue y Operacion

## Variables de entorno

```bash
PORT=80
HOST=0.0.0.0
BACKEND_LANG=en
MAX_BATCH_ITEMS=32
SID2_UNIVERSE=1
CONTAINER_NAME=steamid-service
DOCKER_NETWORK=steamid-network
MEMORY_LIMIT=32m
CPU_LIMIT=0.2
HEALTH_CHECK_INTERVAL=30s
HEALTH_CHECK_TIMEOUT=5s
HEALTH_CHECK_RETRIES=3
```

La base recomendada es [.env.example](../.env.example).

## Docker Compose

### Desarrollo

```bash
docker compose -f docker-compose.dev.yml up -d --build
docker compose -f docker-compose.dev.yml logs -f steamid-service
docker compose -f docker-compose.dev.yml down
```

### Produccion

```bash
docker compose -f docker-compose.yml up -d
docker compose -f docker-compose.yml logs -f steamid-service
docker compose -f docker-compose.yml down
```

## Docker directo

```bash
docker build -t steamid-service .
docker run -d -p 80:80 --name steamid-service steamid-service
```

## Healthcheck

- El contenedor usa [healthcheck.sh](../healthcheck.sh).
- En Compose el healthcheck se ejecuta con `CMD-SHELL`.
- El endpoint `/health` devuelve `HEALTHY` cuando la autoprueba interna pasa.

## Operacion

### Logs

- Startup logs estructurados en JSON.
- Access logs HTTP estructurados en JSON.
- Los health checks exitosos de `/health` no se registran para reducir ruido.

### Build local

```bash
make deps
make test
make lint
make gosec
make build
```

## Swagger

La documentacion OpenAPI se genera manualmente:

```bash
make swagger
```

Los archivos generados quedan en:

- `go/internal/app/docs/docs.go`
- `go/internal/app/docs/swagger.json`
- `go/internal/app/docs/swagger.yaml`
