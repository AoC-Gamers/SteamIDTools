# Arquitectura

## Componentes

### Backend Go

- Entry point: `go/cmd/steamid-service/main.go`
- App interna: `go/internal/app`
- OpenAPI generado: `go/internal/app/docs`
- i18n embebido: `go/internal/app/lang`

Responsabilidades:

- Validacion y conversion de identificadores Steam.
- Exposicion HTTP de endpoints `text/plain`.
- Batch en formato Valve KeyValue.
- Logs JSON con `zerolog`.
- UI Swagger y artefactos OpenAPI.

### SourceMod

- Include offline para conversiones locales.
- Plugin principal con comandos de prueba e integracion HTTP.
- Providers por extension: `SteamWorks` y `system2`.

## Flujo del backend

1. El servidor recibe la request.
2. Se resuelve idioma por `Accept-Language`.
3. Se valida el `steamid`.
4. Se ejecuta la conversion o batch.
5. Se responde en `text/plain`.
6. Se registra el access log JSON.

## Batch

- Entrada: lista separada por comas.
- Validacion: límite, duplicados y formato.
- Salida: Valve KeyValue.

## Logging

- Startup logs estructurados.
- Access logs estructurados.
- Health checks exitosos no se registran para reducir ruido.

## Swagger

- Las anotaciones viven en el código Go.
- La generacion no ocurre al iniciar el servicio.
- Se actualiza manualmente con `make swagger`.

## Versionado

El repo usa versionado diferenciado por componente. Ver [CHANGELOG.md](../CHANGELOG.md).
