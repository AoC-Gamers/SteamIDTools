# Integracion SourceMod

El proyecto incluye dos cosas para SourceMod:

- Un include reutilizable con conversiones offline.
- Un plugin API (`steamidtools.sp`) para conversiones online contra el backend.
- Un plugin demo (`steamidtools_test.sp`) que consume esa API.

## Archivos principales

- `sourcemod/scripting/include/steamidtools.inc`
- `sourcemod/scripting/steamidtools.sp`
- `sourcemod/scripting/steamidtools_test.sp`
- `sourcemod/scripting/steamidtools/steamidtools_steamworks.sp`
- `sourcemod/scripting/steamidtools/steamidtools_system2.sp`

## Conversiones offline

El include permite conversiones sin backend HTTP.

Casos soportados:

- `AccountID -> SteamID2`
- `AccountID -> SteamID3`
- `SteamID2 -> AccountID`
- `SteamID3 -> AccountID`
- `SteamID2 -> SteamID3`
- `SteamID3 -> SteamID2`

El universo default para `SteamID2` es `1`.

Si necesitas otro valor en compile-time:

```sourcepawn
#define STEAMIDTOOLS_SID2_UNIVERSE 0
#include <steamidtools>
```

## Plugin API HTTP

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
#include <steamidtools>

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
