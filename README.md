# SteamIDTools

Biblioteca SourcePawn 4.0.0 para convertir AccountID, SteamID2, SteamID3 y
SteamID64. Los stocks se compilan como parte de cada plugin consumidor.

## Uso

Elegir una revisión Git y copiar `steamidtools.inc` y el directorio
`steamidtools/` desde [`addons/sourcemod/scripting/include/`](addons/sourcemod/scripting/include/)
al proyecto consumidor. Recompilar el plugin:

```sourcepawn
#include <steamidtools>

int accountId;
char steamId64[32];
if (SteamIDTools_TryParseAccountID("4294967295", accountId))
    SteamIDTools_AccountIDToSteamID64(accountId, steamId64, sizeof(steamId64));
```

AccountID conserva los 32 bits sin signo en una celda SourcePawn; comprobar
`accountId != 0` y usar `SteamIDTools_FormatAccountID` para imprimirlo.
SteamID64 siempre es una cadena. Los validadores comprueban formato y rango,
no la existencia de una cuenta ni su autorizacion.

## Estructura

- `addons/sourcemod/scripting/include/steamidtools.inc`: tipos y conversiones puras.
- `addons/sourcemod/scripting/include/steamidtools/clients.inc`: consultas de clientes.
- `addons/sourcemod/scripting/include/steamidtools/commands.inc`: argumentos de comandos.
- `docs/` contiene la referencia de la API y la guía de migración.

## Documentacion y versiones

- [Indice](docs/index.md)
- [Migracion desde 2.x/3.x](docs/migration.md)
- [API y conversiones](docs/sourcemod.md)
- [Referencia SteamID](docs/steamid-reference.md)
- [Changelog](CHANGELOG.md)

El toolkit usa SemVer. Para fijar una dependencia, registra el SHA de la
revisión que copiaste.

## Licencia

El código propio de SteamIDTools se distribuye bajo la
[GPL-3.0 o posterior](LICENSE), según la licencia del include original.
