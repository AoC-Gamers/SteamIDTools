# SteamIDTools

Toolkit SourcePawn 4.0.0 para convertir AccountID, SteamID2, SteamID3 y
SteamID64 localmente. No requiere backend, conexion HTTP, System2, SteamWorks
ni un plugin residente.

## Uso

Copiar `steamidtools.inc` y el directorio `steamidtools/` desde
`addons/sourcemod/scripting/include/` al proyecto consumidor y recompilarlo:

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

## Desarrollo

```bash
make deps-smx build-smx
python3 scripts/test-sourcepawn-offline.py --prepare-vm
make test-offline
make package-smx
make release-smx
make check-package
```

El build prepara los includes sin requerir compilador. El ZIP contiene
includes y documentacion, sin plugins ni extensiones. La suite ejecuta el
include real con JIT e interprete y un oraculo Python independiente.

## Estructura

- `addons/sourcemod/scripting/include/steamidtools.inc`: tipos y conversiones puras.
- `addons/sourcemod/scripting/include/steamidtools/clients.inc`: consultas de clientes.
- `addons/sourcemod/scripting/include/steamidtools/commands.inc`: argumentos de comandos.
- `tests/`: corpus SourcePawn, adaptadores VM y pruebas del paquete.
- `scripts/`: toolchain, compilacion, validacion y empaquetado.
- `docs/`: referencia, contratos, build y migracion.
- `tmp/`: logs, respaldos y fixtures temporales; ignorado por Git.
- `deps/`, `.build/` y `dist/`: dependencias y salidas locales ignoradas.

`make clean` elimina las salidas generadas y conserva la toolchain y la VM.

## Documentacion y versiones

- [Indice](docs/index.md)
- [Migracion desde 2.x/3.x](docs/migration.md)
- [Conversiones y pruebas](docs/sourcemod.md)
- [Referencia SteamID](docs/steamid-reference.md)
- [Changelog](CHANGELOG.md)

Versionado SemVer del toolkit. Tags `sourcemod/vX.Y.Z`; canales
`channel/develop` y `channel/latest`. El backend anterior queda conservado en
la rama local `codex/archive-http-backend`; no se publica como parte de 4.x.
