# API HTTP

Todas las respuestas son `text/plain`.

- Respuesta individual: valor convertido.
- Respuesta batch: formato Valve KeyValue.

## Endpoints

### Desde SteamID64

- `GET /SID64toAID?steamid=76561197960287930`
  Respuesta: `22202`
- `GET /SID64toSID2?steamid=76561197960287930`
  Respuesta: `STEAM_1:0:11101`
- `GET /SID64toSID3?steamid=76561197960287930`
  Respuesta: `[U:1:22202]`

### Hacia SteamID64

- `GET /AIDtoSID64?steamid=22202`
  Respuesta: `76561197960287930`
- `GET /SID2toSID64?steamid=STEAM_1:0:11101`
  Respuesta: `76561197960287930`
- `GET /SID3toSID64?steamid=[U:1:22202]`
  Respuesta: `76561197960287930`

### Salud

- `GET /health`
  Respuesta: `HEALTHY`

### Swagger

- `GET /swagger/index.html`

## Batch

Se soportan valores separados por coma en `steamid`.

Ejemplo:

```bash
curl "http://localhost:80/SID64toAID?steamid=76561197960287930,76561197960287931,76561197960287932"
```

Respuesta:

```text
"SteamIDTools"
{
    "76561197960287930" "22202"
    "76561197960287931" "22203"
    "76561197960287932" "22204"
}
```

Límite configurable por `MAX_BATCH_ITEMS`. El default actual es `32`.

## Parametros

- `steamid`: valor a convertir o lista separada por comas.
- `nullterm=1`: agrega terminador NUL a la respuesta.

## Codigos HTTP

| Codigo | Uso |
|--------|-----|
| `200` | Conversion exitosa |
| `400` | Error de validacion o formato |
| `404` | Endpoint invalido |
| `503` | Servicio no saludable |

## Errores de validacion

| Error |
|-------|
| `Missing required parameter` |
| `Invalid SteamID format provided` |
| `SteamID length is incorrect` |
| `Contains invalid characters` |
| `Invalid SteamID2 format (expected STEAM_X:Y:Z)` |
| `Invalid SteamID3 format (expected [U:1:XXXXXXXX])` |
| `Invalid SteamID64 format or range` |
| `Invalid AccountID (must be numeric and positive)` |

## Idioma de errores

La API detecta `Accept-Language` y responde errores en `en` o `es`.

Ejemplos:

```bash
curl -H "Accept-Language: es" "http://localhost:80/SID64toAID"
curl -H "Accept-Language: es" "http://localhost:80/SID64toAID?steamid=123"
```
