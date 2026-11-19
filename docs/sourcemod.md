# Integracion SourceMod offline

## Instalacion y responsabilidades

Copiar `steamidtools.inc` y el directorio `steamidtools/` desde
`addons/sourcemod/scripting/include/` al proyecto consumidor y recompilarlo.

- `#include <steamidtools>` declara tipos, constantes, formatos, conversiones y URLs.
- `#include <steamidtools/clients>` agrega obtener y buscar clientes conectados.
- `#include <steamidtools/commands>` agrega argumentos normalizados y reconstruccion
  de identidades. No incluye el modulo de clientes.

Los dos módulos importan el include principal. Cada stock se compila como parte
del plugin consumidor. Las búsquedas devuelven cero para una identidad inválida
y -1 para una cuenta sin conexión.
Validar formato no acredita la existencia de una cuenta ni concede permisos.
Cada consumidor conserva sus comprobaciones de autorizacion y persistencia.

Obtén los includes de una revisión Git. Para actualizar plugins consumidores
que usaban el binario HTTP, consulta la [migración](migration.md).

## Conversiones offline

`steamidtools.inc` permite conversiones sin backend HTTP.

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
#include <steamidtools>
```
