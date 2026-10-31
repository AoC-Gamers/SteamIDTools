# Migracion a SteamIDTools 4.x

## Desde el toolkit offline 3.x

4.0.0 reorganiza los includes publicos sin cambiar nombres de funciones ni
su comportamiento. Los antiguos `steamidtools_stock.inc` y
`steamidtools_helpers.inc` se retiran, sin wrappers de compatibilidad.

- Usar `<steamidtools>` para tipos y conversiones puras.
- Agregar `<steamidtools/clients>` al usar `GetClientAccountID`,
  `FindClientByAccountID`, `FindClientBySteamID2`, `FindClientBySteamID3` o
  `IsValidClientIndex`.
- Sustituir `<steamidtools_helpers>` por `<steamidtools/commands>`.

Copiar el include principal y el directorio de modulos juntos; retirar las
copias anteriores y recompilar los consumidores. Las conversiones conservan
los patrones uint32, strings SteamID64 y las condiciones de error/buffer.
No reintroducir dependencias de un plugin cargado para usar estos includes.

## Desde la API online 2.x

La API HTTP y el backend Go fueron retirados en 3.0.0 y siguen ausentes.

Sustituir `SteamIDTools_RequestConversion` por los conversores locales:
`SteamIDTools_SteamID64ToAccountID`, `SteamIDTools_AccountIDToSteamID64`,
`SteamID2ToAccountID`, `SteamID3ToAccountID`, `AccountIDToSteamID2` y
`AccountIDToSteamID3`. Un batch local debe procesarse en lotes acotados por frame.
La conversion local termina inmediatamente; conservar la revalidacion de
permisos, identidad y contexto propia de cada accion.

Retirar listeners `SteamIDTools_OnRequestFinished` y de estado del backend,
providers, salud y contextos de requests que ya no tengan uso. No hay stubs ni
emulacion de callbacks online. Recompilar todos los consumidores con los nuevos
includes y distribuir sus SMX juntos cuando se autorice instalar.

La configuracion de URL/health/debug deja de existir. En instalaciones previas,
un despliegue autorizado debera retirar el antiguo `steamidtools.smx` y su CFG:
los paquetes nuevos no borran archivos ya instalados. Detener o eliminar un
backend desplegado es una operacion separada; esta migracion de fuentes no lo
hace. No desinstalar SteamWorks ni System2 si otros plugins los usan.

BanSystem-Legacy conserva llamadas online: usar su version de includes y el
SteamIDTools anterior de `codex/archive-http-backend` hasta una migracion propia.
No reemplazar sus includes por 4.x. No se eliminan imagenes ni releases remotos.
