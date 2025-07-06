# Servicio de Conversión SteamID (Go)

Servicio web de alto rendimiento para conversión de SteamID específicamente diseñado para servidores de Left 4 Dead 2, donde el motor no soporta cálculos de 64 bits nativamente.

## 🚀 Ventajas

- 🐳 **5-10x imagen Docker más pequeña** (~15MB vs ~100MB)
- 🔧 **Binario estático** - sin dependencias de runtime
- 🚀 **Inicio ultra-rápido** - listo en <1 segundo
- 💾 **Menor uso de memoria** (~16MB vs ~50MB)
- 📦 **Procesamiento por lotes** - convierte múltiples IDs a la vez
- 🗝️ **Formato KeyValue** - salida compatible con Valve para lotes

## Inicio Rápido

### Opción 1: Usando Docker (Recomendado)

#### ¿Qué archivo o script usar?

**docker-compose.dev.yml**

✅ Usa este archivo si:

- Quieres construir la imagen Docker localmente con el código fuente.
- Estás desarrollando o realizando pruebas.
- Necesitas hacer cambios frecuentes en el código Go y ver los resultados rápidamente.

📦 Ejemplo de uso:

```bash
docker compose -f docker-compose.dev.yml up --build
```

**docker-compose.yml**

✅ Usa este archivo si:

- Quieres descargar la imagen ya construida desde el registro Docker Hub o GitHub Packages.
- Estás desplegando en entornos de producción.
- No necesitas reconstruir el binario Go manualmente.

📦 Ejemplo de uso:

```bash
docker compose -f docker-compose.yml up -d
```

### Opción 2: Ejecución Directa (Desarrollo)

```bash
# Con Go instalado localmente
cd go
go run main.go [puerto]
# Usa puerto 80 por defecto

# Probar el servicio
curl "http://localhost:80/SID64toAID?steamid=76561197960287930"
```

## Ejecución directa con script (Linux/macOS y Windows)

### Linux/macOS

```bash
# Iniciar en modo normal (puerto 80, todas las interfaces)
./serve.sh

# Iniciar en puerto 3000, solo localhost
./serve.sh -p 3000 -h localhost

# Iniciar en modo debug (logs extra)
./serve.sh --debug
```

### Windows (PowerShell)

```powershell
# Iniciar en modo normal (puerto 80, todas las interfaces)
.\serve.ps1

# Iniciar en puerto 3000, solo localhost
.\serve.ps1 -Port 3000 -Host localhost

# Iniciar en modo debug (logs extra)
.\serve.ps1 -Debug
```

## APIs Disponibles

Todas las respuestas son en texto plano, conteniendo únicamente el resultado de la conversión.

### Conversiones desde SteamID64:

- **`/SID64toAID`** (SteamID64 a AccountID)
  ```
  GET http://localhost:80/SID64toAID?steamid=76561197960287930
  Respuesta: 22202
  ```

- **`/SID64toSID2`** (SteamID64 a SteamID2)
  ```
  GET http://localhost:80/SID64toSID2?steamid=76561197960287930
  Respuesta: STEAM_1:0:11101
  ```

- **`/SID64toSID3`** (SteamID64 a SteamID3)
  ```
  GET http://localhost:80/SID64toSID3?steamid=76561197960287930
  Respuesta: [U:1:22202]
  ```

### Conversiones a SteamID64:

- **`/AIDtoSID64`** (AccountID a SteamID64)
  ```
  GET http://localhost:80/AIDtoSID64?steamid=22202
  Respuesta: 76561197960287930
  ```

- **`/SID2toSID64`** (SteamID2 a SteamID64)
  ```
  GET http://localhost:80/SID2toSID64?steamid=STEAM_1:0:11101
  Respuesta: 76561197960287930
  ```

- **`/SID3toSID64`** (SteamID3 a SteamID64)
  ```
  GET http://localhost:80/SID3toSID64?steamid=[U:1:22202]
  Respuesta: 76561197960287930
  ```

### Endpoint de Salud:

- **`/health`** (Verificación de estado del servicio)
  ```
  GET http://localhost:80/health
  Respuesta: HEALTHY
  ```

## Procesamiento por Lotes

El servicio soporta procesamiento por lotes usando valores separados por comas:

```bash
# Convertir múltiples SteamID64 a AccountID (máximo 32 por defecto)
curl "http://localhost:80/SID64toAID?steamid=76561197960287930,76561197960287931,76561197960287932"
```

La respuesta será en formato KeyValue de Valve:
```
"SteamIDTools"
{
    "76561197960287930" "22202"
    "76561197960287931" "22203"
    "76561197960287932" "22204"
}
```

**Límite:** Máximo configurable por `MAX_BATCH_ITEMS` (por defecto 32 elementos por lote).

### Límite de procesamiento por lotes

Por defecto, el máximo de elementos permitidos en una consulta batch es **32**. Puedes modificar este límite estableciendo la variable de entorno `MAX_BATCH_ITEMS`:

En Docker Compose, puedes ajustar el valor en el archivo `docker-compose.dev.yml`:

```yaml
environment:
  - MAX_BATCH_ITEMS=16
```

> Si excedes el límite, el backend devolverá un error y no procesará la solicitud.

## Configuración

### Variables de Entorno

```bash
PORT=80              # Puerto del servicio
HOST=0.0.0.0         # IP de bind (0.0.0.0 para todas las interfaces)
SID2_UNIVERSE=1      # Universo para formato SteamID2 (STEAM_X:Y:Z)
```

### Archivo .env

Copia `.env.example` a `.env` y ajusta los valores según tu necesidad.

### Idioma del backend (logs y consola)

Puedes definir el idioma de los mensajes internos del backend (logs y consola) usando la variable de entorno `BACKEND_LANG`.

- Ejemplo para español:
  ```yaml
  environment:
    - BACKEND_LANG=es
  ```
- Ejemplo para inglés (por defecto):
  ```yaml
  environment:
    - BACKEND_LANG=en
  ```

Esto afecta solo los mensajes de arranque y logs del backend, no las respuestas HTTP a los clientes.

En Docker Compose ya está disponible la variable:
```yaml
environment:
  - BACKEND_LANG=${BACKEND_LANG:-en}
```
Puedes sobreescribirla en tu `.env` o directamente en el archivo Compose.

## Comandos Docker

### Usando Makefile (Recomendado)
```bash
make help          # Mostrar ayuda
make build          # Construir imagen
make test           # Ejecutar pruebas
make deploy         # Desplegar servicio
make stop           # Detener servicio
make logs           # Ver logs
make clean          # Limpiar todo
make all            # Construir, probar y desplegar
```

### Usando docker-compose directamente
```bash
# Construir y iniciar
docker-compose up -d

# Ver logs
docker-compose logs -f

# Detener
docker-compose down
```

### Usando Docker directamente
```bash
# Construir imagen
docker build -t steamid-service .

# Ejecutar contenedor
docker run -d -p 80:80 --name steamid-service steamid-service
```

## Uso desde SourcePawn


## Requisitos

### Para ejecución directa:
- Go 1.21 o superior
- Solo usa librerías estándar de Go (no requiere dependencias externas)

### Para Docker:
- Docker 20.10+
- Docker Compose 1.29+

## Ejemplos de Uso

### Desde línea de comandos:
```bash
# Conversión individual
curl "http://localhost:80/SID64toAID?steamid=76561197960287930"
# Respuesta: 22202

curl "http://localhost:80/AIDtoSID64?steamid=22202"
# Respuesta: 76561197960287930

curl "http://localhost:80/SID2toSID64?steamid=STEAM_1:0:11101"
# Respuesta: 76561197960287930

# Conversión por lotes
curl "http://localhost:80/SID64toAID?steamid=76561197960287930,76561197960287931"
# Respuesta en formato KeyValue
```

### Health Check:
```bash
curl "http://localhost:80/health"
# Respuesta: HEALTHY
```

## Arquitectura

El servicio está diseñado para:
- Ejecutarse en la misma máquina que los gameservers
- **Respuestas ultra-rápidas** (solo texto plano, sin JSON overhead)
- **Sin dependencias externas** (binario estático compilado)
- Compatible con el sistema de HTTP requests de SteamWorks
- Containerizado para fácil despliegue
- Verificaciones de salud integradas
- **Uso mínimo de recursos** (16MB RAM, <1% CPU)
- **Inicio instantáneo** (<1 segundo)
- **Procesamiento por lotes** con formato KeyValue de Valve
- **Configuración flexible** del universo SteamID2

## Manejo de Errores

El servicio proporciona mensajes de error y códigos de estado HTTP:

### Códigos de Error HTTP

| Código HTTP | Descripción |
|-------------|-------------|
| `200` | Conversión exitosa |
| `400` | Error en la solicitud (parámetros inválidos) |
| `500` | Error interno del servidor |
| `503` | Servicio no disponible |

### Tipos de Errores de Validación

| Error | Descripción | Ejemplo | Idioma |
|-------|-------------|---------|--------|
| `Missing required parameter` / `Falta un parámetro obligatorio` | Falta el parámetro `steamid` | `GET /SID64toAID` (sin parámetros) | en/es |
| `Invalid SteamID format provided` / `Formato de SteamID inválido` | Formato de SteamID incorrecto | `steamid=invalid_format` | en/es |
| `SteamID length is incorrect` / `La longitud del SteamID es incorrecta` | Longitud incorrecta del SteamID | `steamid=123` (muy corto) | en/es |
| `Contains invalid characters` / `Contiene caracteres inválidos` | Caracteres no válidos | `steamid=76561abc123` | en/es |
| `Invalid SteamID2 format (expected STEAM_X:Y:Z)` / `Formato de SteamID2 inválido (se espera STEAM_X:Y:Z)` | Formato SteamID2 inválido | `steamid=STEAM_1:2` | en/es |
| `Invalid SteamID3 format (expected [U:1:XXXXXXXX])` / `Formato de SteamID3 inválido (se espera [U:1:XXXXXXXX])` | Formato SteamID3 inválido | `steamid=[U:1:]` | en/es |
| `Invalid SteamID64 format or range` / `Formato o rango de SteamID64 inválido` | SteamID64 fuera de rango | `steamid=123456` | en/es |
| `Invalid AccountID (must be numeric and positive)` / `AccountID inválido (debe ser numérico y positivo)` | AccountID inválido | `steamid=0` o `steamid=-1` | en/es |

## 🌐 Internacionalización de errores (i18n)

El backend detecta automáticamente el idioma preferido del usuario a través del header HTTP `Accept-Language` y responde los mensajes de error en español (`es`) o inglés (`en`).

- Los mensajes de error y contexto se almacenan en archivos separados por idioma en el directorio `go/lang/`:
  - `go/lang/messages_en.json` (inglés)
  - `go/lang/messages_es.json` (español)
- El backend carga estos archivos al iniciar y selecciona el idioma adecuado según la cabecera HTTP.
- Si el cliente envía `Accept-Language: es`, los errores se devuelven en español.
- Si no se especifica o se usa otro idioma, los errores se devuelven en inglés.
- Los mensajes de log y consola siempre están en inglés para facilitar el soporte.

### Ejemplo de uso con curl

```bash
# Error de parámetro faltante en español
curl -H "Accept-Language: es" "http://localhost:80/SID64toAID"
# Respuesta: se requiere el parámetro steamid

# Error de SteamID inválido en español
curl -H "Accept-Language: es" "http://localhost:80/SID64toAID?steamid=123"
# Respuesta: La longitud del SteamID es incorrecta

# Error de parámetro faltante en inglés (por defecto)
curl "http://localhost:80/SID64toAID"
# Response: steamid parameter required
```

> Puedes probar cualquier endpoint con el header `Accept-Language: es` para obtener los mensajes en español.

### Estructura de los archivos de idioma

Cada archivo contiene un objeto JSON plano con las claves y mensajes traducidos. Ejemplo para inglés:

```json
{
  "invalid_length": "SteamID length is incorrect",
  "invalid_characters": "Contains invalid characters",
  "invalid_format": "Invalid SteamID format provided"
  // ...otras claves...
}
```

Y para español:

```json
{
  "invalid_length": "La longitud del SteamID es incorrecta",
  "invalid_characters": "Contiene caracteres inválidos",
  "invalid_format": "Formato de SteamID inválido"
  // ...otras claves...
}
```

> Los archivos deben estar en `go/lang/` y pueden ser editados para agregar más idiomas o mensajes personalizados.

---

# Ejemplos de Integración en SourcePawn

Aquí ejemplos prácticos para usar el servicio SteamIDTools desde SourcePawn, tanto offline (sin backend) como mediante llamadas HTTP usando SteamWorks o System2.

### 🔹 Ejemplo Offline (sin HTTP)
Convierte SteamIDs localmente sin depender del backend Go:

```sourcepawn
#include <sourcemod>
#include <steamidtools.inc>

public void OnPluginStart()
{
    RegConsoleCmd("sm_sidtools_offline", CmdOfflineConversion);
}

public Action CmdOfflineConversion(int client, int args)
{
    int accountId = GetClientAccountID(client);

    char sid2[MAX_AUTHID_LENGTH];
    char sid3[MAX_AUTHID_LENGTH];
    char sid64[MAX_AUTHID_LENGTH];

    // AccountID → SteamID2
    if (AccountIDToSteamID2(accountId, sid2, sizeof(sid2)))
    {
        PrintToChat(client, "AccountID %d → SteamID2: %s", accountId, sid2);
    }

    // AccountID → SteamID3
    if (AccountIDToSteamID3(accountId, sid3, sizeof(sid3)))
    {
        PrintToChat(client, "AccountID %d → SteamID3: %s", accountId, sid3);
    }

    // AccountID → SteamID64
    if (AccountIDToSteamID64(accountId, sid64, sizeof(sid64)))
    {
        PrintToChat(client, "AccountID %d → SteamID64: %s", accountId, sid64);
    }

    // SteamID2 → AccountID
    int newAccountId = SteamID2ToAccountID(sid2);
    PrintToChat(client, "SteamID2 %s → AccountID: %d", sid2, newAccountId);

    // SteamID3 → AccountID
    newAccountId = SteamID3ToAccountID(sid3);
    PrintToChat(client, "SteamID3 %s → AccountID: %d", sid3, newAccountId);

    return Plugin_Handled;
}
```

**Ventajas:**
- Rápido e instantáneo.
- No requiere acceso al backend ni red.
- Perfecto para plugins simples.

### 🔹 Ejemplo usando SteamWorks
Ejemplo realizando petición HTTP con SteamWorks:

```sourcepawn
#include <sourcemod>
#include <steamworks>
#include <steamidtools.inc>

public void OnPluginStart()
{
    RegConsoleCmd("sm_sidtools_steamworks", CmdSteamWorksExample);
}

public Action CmdSteamWorksExample(int client, int args)
{
    char url[256];
    Format(url, sizeof(url),
        "http://localhost:80/SID64toAID?steamid=%s",
        "76561197960287930"
    );

    Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
    SteamWorks_SetHTTPRequestContextValue(hRequest, client);
    SteamWorks_SetHTTPCallbacks(hRequest, OnSteamWorksResponse);
    SteamWorks_SendHTTPRequest(hRequest);

    PrintToChat(client, "[SteamIDTools] Request sent via SteamWorks!");

    return Plugin_Handled;
}

public void OnSteamWorksResponse(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data)
{
    int client = data;

    if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
    {
        PrintToChat(client, "[SteamIDTools] HTTP Error!");
        CloseHandle(hRequest);
        return;
    }

    int size;
    SteamWorks_GetHTTPResponseBodySize(hRequest, size);

    char response[128];
    SteamWorks_GetHTTPResponseBodyData(hRequest, response, sizeof(response));

    PrintToChat(client, "[SteamIDTools] SteamID64 → AccountID: %s", response);

    CloseHandle(hRequest);
}
```

**Ventajas:**
- Integrado con SourceMod/SteamWorks.

### 🔹 Ejemplo usando System2
Ejemplo moderno usando System2 (recomendado si no usas SteamWorks):

```sourcepawn
#include <sourcemod>
#include <system2>
#include <steamidtools.inc>

public void OnPluginStart()
{
    RegConsoleCmd("sm_sidtools_sys2", CmdSystem2Example);
}

public Action CmdSystem2Example(int client, int args)
{
    char url[256];
    Format(url, sizeof(url),
        "http://localhost:80/SID64toSID2?steamid=%s",
        "76561197960287930"
    );

    System2HTTPRequest req = new System2HTTPRequest(OnSystem2Response, url);
    req.Any = client;
    req.GET();

    PrintToChat(client, "[SteamIDTools] Request sent via System2!");

    return Plugin_Handled;
}

public void OnSystem2Response(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
    int client = view_as<int>(request.Any);

    if (!success || response.StatusCode != 200)
    {
        PrintToChat(client, "[SteamIDTools] HTTP Error: %s", error);
        return;
    }

    char data[128];
    response.GetContent(data, sizeof(data));

    PrintToChat(client, "[SteamIDTools] SteamID64 → SteamID2: %s", data);
}
```

**Ventajas:**
- Moderno y asíncrono.
- Compatible con HTTPS y proxies.
- Flexible para todo tipo de peticiones.

### 🔹 Ejemplo Batch con System2
Tu backend soporta conversiones por lotes. Ejemplo:

```sourcepawn
#include <sourcemod>
#include <system2>
#include <steamidtools.inc>

public void OnPluginStart()
{
    RegConsoleCmd("sm_sidtools_batch", CmdBatchSystem2);
}

public Action CmdBatchSystem2(int client, int args)
{
    char url[512];
    Format(url, sizeof(url),
        "http://localhost:80/SID64toAID?steamid=%s",
        "76561197960287930,76561197960287931,76561197960287932"
    );

    System2HTTPRequest req = new System2HTTPRequest(OnBatchSystem2Response, url);
    req.Any = client;
    req.GET();

    PrintToChat(client, "[SteamIDTools] Batch request sent via System2!");

    return Plugin_Handled;
}

public void OnBatchSystem2Response(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
    int client = view_as<int>(request.Any);

    if (!success || response.StatusCode != 200)
    {
        PrintToChat(client, "[SteamIDTools] HTTP Error: %s", error);
        return;
    }

    char data[512];
    response.GetContent(data, sizeof(data));

    PrintToChat(client, "[SteamIDTools] Batch Response:\n%s", data);
}
```

**Ventajas:**
- Compatible con lotes grandes.
- Respuesta en KeyValue, ideal para parsear resultados múltiples.

---

### ✅ ¿Qué método usar?

| Método     | Cuándo usarlo                        |
|------------|--------------------------------------|
| Offline    | Para conversiones locales rápidas.    |
| SteamWorks | Si ya usas SteamWorks.               |
| System2    | Para máxima flexibilidad HTTP.        |
