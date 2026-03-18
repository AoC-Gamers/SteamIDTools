# Referencia de SteamID

Esta guia resume la representacion de SteamID usada por SteamIDTools, tomando como referencia la documentacion publica de Valve sobre SteamID y enfocandose en los formatos que el proyecto convierte y valida.

Fuente principal:

- https://developer.valvesoftware.com/wiki/SteamID

## Alcance del proyecto

SteamIDTools trabaja principalmente con cuentas individuales de jugadores.

En la documentacion de Valve esto corresponde a:

- universo publico: `1`
- tipo de cuenta individual: `U`
- conversiones mas comunes entre `AccountID`, `SteamID2`, `SteamID3` y `SteamID64`

La documentacion de Valve describe mas universos y mas tipos de cuenta, pero el caso comun del proyecto es el de cuentas individuales publicas.

## Resumen rapido

| Formato | Ejemplo | Uso comun |
|---------|---------|-----------|
| AccountID | `66138017` | identificador numerico interno de la cuenta |
| SteamID2 | `STEAM_1:1:33069008` | formato textual clasico usado por Source |
| SteamID3 | `[U:1:66138017]` | formato textual mas explicito |
| SteamID64 | `76561198026403745` | identificador de 64 bits usado por perfiles y APIs |

Todos estos ejemplos representan la misma cuenta individual publica.

## AccountID

El `AccountID` es el numero base de la cuenta dentro de los formatos de Steam para usuarios individuales.

En la explicacion de Valve:

- en `SteamID2`, corresponde al valor reconstruido como `Z * 2 + Y`
- en `SteamID3`, corresponde al valor numerico final dentro de `[U:1:W]`
- en `SteamID64`, corresponde al desplazamiento sumado sobre la base de cuentas individuales

Para SteamIDTools, este valor es el eje de conversion entre formatos.

## SteamID2

Formato textual clasico:

```text
STEAM_X:Y:Z
```

Significado segun Valve:

- `X`: universo
- `Y`: bit de paridad del account number, normalmente `0` o `1`
- `Z`: numero de cuenta reducido

Relacion con `AccountID`:

```text
AccountID = Z * 2 + Y
```

Ejemplo:

```text
STEAM_1:1:33069008
AccountID = 33069008 * 2 + 1 = 66138017
```

Notas practicas:

- en motores Source viejos podia verse `STEAM_0`, mientras que juegos modernos suelen usar `STEAM_1`
- SteamIDTools usa por defecto universo `1` al reconstruir `SteamID2`

## SteamID3

Formato textual expandido:

```text
[U:1:W]
```

Significado:

- `U`: tipo de cuenta individual
- `1`: universo publico
- `W`: `AccountID`

Relacion con `AccountID`:

```text
AccountID = W
```

Ejemplo:

```text
[U:1:66138017]
```

Este formato elimina la ambiguedad de `SteamID2` porque separa explicitamente el tipo de cuenta y deja visible el `AccountID` completo.

## SteamID64

Valve describe el identificador de 64 bits como una estructura con campos de universo, tipo, instancia y numero de cuenta.

Para cuentas individuales publicas, SteamIDTools trabaja con esta base decimal:

```text
76561197960265728
```

Que corresponde al bloque base documentado por Valve para cuentas individuales publicas.

Relacion con `AccountID`:

```text
SteamID64 = 76561197960265728 + AccountID
```

Ejemplo:

```text
AccountID = 66138017
SteamID64 = 76561197960265728 + 66138017
SteamID64 = 76561198026403745
```

## Conversiones entre formatos

Relaciones usadas por el proyecto:

```text
SteamID2 -> AccountID:  AccountID = Z * 2 + Y
SteamID3 -> AccountID:  AccountID = W
AccountID -> SteamID3:  [U:1:AccountID]
AccountID -> SteamID64: 76561197960265728 + AccountID
```

Para cuentas individuales publicas:

```text
SteamID2  <-> AccountID <-> SteamID3
                      \
                       \-> SteamID64
```

## Validacion recomendada

Tomando como base la documentacion de Valve para cuentas individuales publicas, una validacion razonable de `SteamID64` debe comprobar:

- longitud exacta de `17` digitos
- solo caracteres numericos
- rango decimal compatible con la base de cuentas individuales publicas
- no usar prefijos fijos como unica regla de validacion

Esto ultimo es importante porque el prefijo decimal visible puede crecer con el tiempo a medida que crece el `AccountID`.

## Rango usado por SteamIDTools

Para cuentas individuales publicas, SteamIDTools documenta el rango decimal:

```text
Minimo: 76561197960265729
Maximo: 76561202255233023
```

Ese maximo sale de:

```text
76561197960265728 + 4294967295
```

Donde `4294967295` es el maximo valor de un entero sin signo de 32 bits para el numero de cuenta.

## Limitaciones y alcance

Esta referencia no intenta cubrir todos los tipos de cuenta descritos por Valve.

Puntos a tener presentes:

- Valve documenta otros tipos de cuenta ademas de `U` individual
- existen otros universos ademas del publico `1`
- SteamIDTools esta orientado al caso comun de jugadores y perfiles individuales
- si el proyecto necesita cubrir tipos de cuenta distintos, la validacion y conversion deben ampliarse explicitamente

## Relacion con SteamIDTools

En este repositorio:

- el include SourceMod usa estas relaciones para conversiones offline
- el backend Go expone conversiones HTTP entre estos formatos
- la validacion debe seguir la estructura documentada por Valve, no heuristicas de prefijos fijos