# Integracion SourceMod

El proyecto incluye dos cosas para SourceMod:

- Un include reutilizable de stocks offline.
- Un include de API online que expone la library del plugin.
- Un plugin API (`steamidtools.sp`) para conversiones online contra el backend.
- Un plugin demo (`steamidtools_test.sp`) que consume esa API.

## Archivos principales

- `sourcemod/scripting/include/steamidtools_stock.inc`
- `sourcemod/scripting/include/steamidtools.inc`
- `sourcemod/scripting/steamidtools.sp`
- `sourcemod/scripting/steamidtools_test.sp`
- `sourcemod/scripting/steamidtools/steamidtools_steamworks.sp`
- `sourcemod/scripting/steamidtools/steamidtools_system2.sp`

## Build local

El carril SourceMod del repo usa:

- `make deps-smx`
- `make build-smx`
- `make package-smx`
- `make release-smx`

El zip final queda en:

- `dist/release/`

## Conversiones offline

`steamidtools_stock.inc` permite conversiones sin backend HTTP.

Casos soportados:

- `AccountID -> SteamID64` mediante `SteamIDTools_AccountIDToSteamID64`
- `SteamID64 -> AccountID` mediante `SteamIDTools_SteamID64ToAccountID`
- `AccountID -> SteamID2`
- `AccountID -> SteamID3`
- `SteamID2 -> AccountID`
- `SteamID3 -> AccountID`
- `SteamID2 -> SteamID3`
- `SteamID3 -> SteamID2`

El universo default para `SteamID2` es `1`.

Desde la version SourceMod `2.5.0`, las conversiones admiten AccountIDs de
`1` a `4294967295`. SourcePawn conserva estos valores como patrones uint32 en
celdas de 32 bits: los mayores de `2147483647` aparecen como enteros negativos.
Usar `accountId != 0` para comprobar identidad y
`SteamIDTools_FormatAccountID` para obtener su representacion decimal.
SteamID64 permanece como cadena; estas conversiones no necesitan backend HTTP.

`SteamIDTools_TryParseUInt32` acepta `0..4294967295` y
`SteamIDTools_TryParseAccountID` excluye cero. Ambos rechazan signos, espacios,
texto sobrante y overflow; admiten ceros iniciales hasta `ACCOUNTID_LENGTH`.
Los conversores a SteamID2, SteamID3 y SteamID64 devuelven `false` si el buffer
es insuficiente, sin modificarlo.

Si necesitas otro valor en compile-time:

```sourcepawn
#define STEAMIDTOOLS_SID2_UNIVERSE 0
#include <steamidtools_stock>
```

### Prueba de regresion offline

La suite compila el include real en un SMX y lo ejecuta con JIT e interprete
de [SourcePawn](https://github.com/alliedmodders/sourcepawn). El oraculo usa
enteros de precision arbitraria de Python, sin consultar el backend HTTP.
Se prueban 12 casos fijos, incluidos los limites de int32/uint32, y 2.048
AccountIDs pseudoaleatorios reproducibles (semilla `550`). Tambien se comprueban
entradas invalidas, SteamID3 de un digito, ceros iniciales, suma decimal y
buffers insuficientes para AccountID, SteamID2, SteamID3 y SteamID64.

Preparacion en Linux x86_64, con Git, Python 3 y un compilador C++ disponibles:

```bash
make deps-smx
python3 scripts/test-sourcepawn-offline.py --prepare-vm
```

El script descarga revisiones fijadas de SourcePawn y AMBuild en `deps/`, agrega
adaptadores de prueba para las primitivas de cadenas de SourceMod y compila el
shell. El log de esa compilacion queda en `deps/sourcepawn-build.log`.
Los SMX y el corpus generado quedan en `.build/stock-tests/`.
Las ejecuciones posteriores usan:

```bash
make test-offline
```

Para contrastar otra copia del include con el mismo corpus:

```bash
python3 scripts/test-sourcepawn-offline.py --stock-include ../otra-copia/steamidtools_stock.inc
```

La salida identifica el SHA256 del include, los casos de borde y los fallos por
seccion. El proceso devuelve un codigo distinto de cero si falla alguna
comprobacion. Las pruebas inversas de SteamID64 se habilitan solamente si la
copia incorpora `ACCOUNTID_UINT32_MAX_STRING` y esas funciones adicionales.

El shell conserva celdas SourcePawn de 32 bits; el adaptador de `StringToInt`
reproduce el limite de `strtoul` de Linux de 32 bits usado por
[SourceMod](https://github.com/alliedmodders/sourcemod/blob/1.12-dev/core/logic/smn_string.cpp).
Los adaptadores cubren unicamente las primitivas que necesita este corpus.
El modo VM no valida clientes, extensiones, callbacks ni la carga en SRCDS.
Los tests de Go y el plugin demo son verificaciones independientes.

La suite cubre los casos de regresion corregidos en `2.5.0`: rechazo del bit alto del
AccountID, SteamID3 cortos y validadores permisivos. Compilar el plugin
correctamente no demuestra que los resultados de conversion sean correctos.

### Plugin de prueba para SRCDS

El mismo harness puede compilarse como plugin SourceMod, sin los adaptadores
de cadenas del shell:

```bash
python3 scripts/test-sourcepawn-offline.py --server-plugin
```

La salida muestra la ruta de `steamidtools_stock_test.smx`. Este binario de
prueba queda fuera del artifact ordinario y no necesita el plugin API HTTP.
Copiarlo a `plugins/disabled/` del servidor y, desde su consola mediante tmux,
ejecutar:

```text
sm plugins load disabled/steamidtools_stock_test.smx
sm_steamidtools_stock_test
```

Para convertir un AccountID concreto y comprobar el retorno al mismo AccountID:

```text
sm_steamidtools_stock_convert 48030081
```

Ambos comandos son exclusivos de la consola del servidor. Cada ejecucion de
la suite reinicia los contadores, procesa conversiones en lotes de 64 casos entre frames y
rechaza un segundo inicio mientras haya una prueba en curso. El resultado
aparece en consola y en `logs/steamidtools_stock_test.log`, relativo al
directorio SourceMod activo (`Path_SM`). La linea `RESULT` debe indicar
`failed=0` y la linea `END` confirma que termino la ejecucion.

Para retirar el harness de memoria:

```text
sm plugins unload disabled/steamidtools_stock_test.smx
```

Este modo verifica las conversiones con los natives reales de SourceMod y la
carga del harness. No requiere jugadores conectados y no prueba callbacks de
clientes ni el flujo de deteccion de Family Sharing.

## Plugin API HTTP

`steamidtools.inc` ya no mezcla stocks offline con la library del plugin. Ahora:

- incluye `steamidtools_stock.inc`
- declara la library `steamidtools`
- expone `natives` y `forwards` del plugin online

`steamidtools.sp` ya no es el plugin de prueba. Ahora:

- registra la library `steamidtools`
- expone `natives` para encolar requests online
- emite un `forward` cuando la respuesta llega
- resuelve internamente el transporte con `SteamWorks` o `system2`

Natives expuestos:

- `SteamIDTools_IsProviderAvailable`
- `SteamIDTools_GetApiBaseUrl`
- `SteamIDTools_RequestConversion`
- `SteamIDTools_RequestBatch`

Forward expuesto:

- `SteamIDTools_OnRequestFinished`

Config:

- ConVar `steamidtools_api_base_url`
- Default actual: `http://localhost:80`

## Plugin demo

`steamidtools_test.sp` es el consumidor de ejemplo de la API.

Comandos:

- `sm_steamidtools <offline|steamworks|system2>`
- `sm_steamidtools_batch <steamworks|system2>`

## Mejoras ya aplicadas

- Encoding seguro del parametro `steamid` para requests HTTP.
- Contexto async seguro usando `userid` en vez de `client index`.
- Menos duplicacion entre `SteamWorks` y `system2`.
- `system2` ya no depende de `StringMap` para labels temporales.

## Ejemplo offline

```sourcepawn
#include <sourcemod>
#include <steamidtools_stock>

public Action CmdOfflineConversion(int client, int args)
{
    int accountId = GetClientAccountID(client);
    char sid2[MAX_AUTHID_LENGTH];

    if (AccountIDToSteamID2(accountId, sid2, sizeof(sid2)))
    {
        PrintToChat(client, "AccountID %d -> SteamID2: %s", accountId, sid2);
    }

    return Plugin_Handled;
}
```

## Ejemplo API online

```sourcepawn
#include <sourcemod>
#include <steamidtools>

StringMap g_RequestClients;

public void OnPluginStart()
{
    g_RequestClients = new StringMap();
}

public Action CmdExample(int client, int args)
{
    int requestId = SteamIDTools_RequestConversion(
        SteamIDToolsProvider_SteamWorks,
        API_SID64toAID,
        "76561197960287930",
        "Lookup"
    );

    if (requestId > 0)
    {
        char key[16];
        IntToString(requestId, key, sizeof(key));
        g_RequestClients.SetValue(key, GetClientUserId(client));
    }

    return Plugin_Handled;
}

public void SteamIDTools_OnRequestFinished(int requestId, SteamIDToolsProvider provider, bool success, bool batch, const char[] endpoint, const char[] input, const char[] result, const char[] tag)
{
    char key[16];
    IntToString(requestId, key, sizeof(key));

    int userId = 0;
    if (!g_RequestClients.GetValue(key, userId))
    {
        return;
    }

    g_RequestClients.Remove(key);

    int client = GetClientOfUserId(userId);
    if (client <= 0 || !IsClientInGame(client))
    {
        return;
    }

    ReplyToCommand(client, "[STEAMIDTOOLS] %s: %s", tag, result);
}
```
