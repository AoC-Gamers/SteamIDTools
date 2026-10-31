# Integracion SourceMod offline

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
El ejemplo y el harness de servidor son verificaciones independientes.

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


## Ejemplo opcional

El build compila `steamidtools_test.sp` fuera del paquete. El comando
`sm_steamidtools_convert <identity>` usa conversiones locales de forma directa.
No requiere provider ni health checks. No se instala ni ejecuta automaticamente.

Ver [migracion](migration.md) para retirar la API HTTP anterior.
