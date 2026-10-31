# Migracion de 2.x a 3.x

3.0.0 retira el backend Go y la API online. Los stocks mantienen sus nombres y
contratos. `steamidtools.inc` ahora importa solo `steamidtools_stock.inc` y no
crea una dependencia de `steamidtools.smx`.

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
No reemplazar sus includes por 3.x. No se eliminan imagenes ni releases remotos.
