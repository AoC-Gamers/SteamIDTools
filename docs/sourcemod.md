# Integracion SourceMod

El proyecto incluye dos cosas para SourceMod:

- Un include reutilizable con conversiones offline.
- Un plugin de ejemplo/uso real con transporte HTTP por `SteamWorks` y `system2`.

## Archivos principales

- `sourcemod/scripting/include/steamidtools.inc`
- `sourcemod/scripting/steamidtools.sp`
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

## Plugin HTTP

El plugin principal expone comandos de prueba:

- `sm_steamidtools <offline|steamworks|system2>`
- `sm_steamidtools_batch <steamworks|system2>`

Config:

- ConVar `steamidtools_api_base_url`
- Default actual: `http://localhost:80`

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

## Ejemplo SteamWorks

```sourcepawn
#include <sourcemod>
#include <steamworks>

public Action CmdExample(int client, int args)
{
    char url[256];
    Format(url, sizeof(url), "http://localhost:80/SID64toAID?steamid=%s", "76561197960287930");

    Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
    SteamWorks_SetHTTPRequestContextValue(request, GetClientUserId(client));
    SteamWorks_SendHTTPRequest(request);
    return Plugin_Handled;
}
```

## Ejemplo System2

```sourcepawn
#include <sourcemod>
#include <system2>

public Action CmdExample(int client, int args)
{
    System2HTTPRequest req = new System2HTTPRequest(OnResponse, "http://localhost:80/SID64toSID2?steamid=76561197960287930");
    req.Any = GetClientUserId(client);
    req.GET();
    return Plugin_Handled;
}
```
