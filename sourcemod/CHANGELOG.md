# SourceMod Changelog

Este archivo sigue el formato de Keep a Changelog y usa SemVer.

## [Unreleased]

### Added

- None.

### Changed

- El provider `SteamWorks` ahora usa `SteamWorks_GetHTTPResponseBodyString(...)` para leer respuestas textuales y JSON, en vez de tratar bodies HTTP crudos como strings manualmente.
- `SteamIDTools_RequestConversion(...)` y `SteamIDTools_RequestBatch(...)` ahora aceptan `SteamIDToolsProvider_Auto` como selector oficial para delegar la eleccion del transporte HTTP al plugin principal.
- La seleccion automatica del provider ahora queda centralizada en `steamidtools.sp`: primero intenta un provider `ready` y, si no existe uno sano todavia, cae a cualquier provider `available`.
- La enum publica `SteamIDToolsProvider` reemplaza `SteamIDToolsProvider_Unknown` por `SteamIDToolsProvider_Auto` como valor `0`, para dejar explicito su uso como selector automatico.

### Fixed

- El flujo HTTP del provider `SteamWorks` ahora cierra el `Handle` del request en todos los caminos de finalizacion del callback.
- Las respuestas truncadas o fallidas al leer el body textual desde `SteamWorks` ahora se reportan como error explicito, en vez de continuar con contenido incompleto.

## [2.4.0] - 2026-03-21

### Added

- Nuevo include `sourcemod/scripting/include/steamidtools_stock.inc` con conversiones y validaciones offline separadas de la API online.

### Changed

- `sourcemod/scripting/include/steamidtools.inc` ahora queda dedicado a la library del plugin, natives y forwards, e incluye `steamidtools_stock.inc`.
- `sourcemod/scripting/include/steamidtools_helpers.inc` ahora depende de `steamidtools_stock.inc`.
- El artifact CI de SourceMod ahora verifica que `steamidtools_stock.inc` quede incluido en el paquete generado.
- `steamidtools.inc`, `steamidtools_stock.inc`, `steamidtools_helpers.inc`, `steamidtools.sp` y `steamidtools_test.sp` ahora usan una sola macro de version publica: `STEAMIDTOOLS_VERSION`.

## [2.3.2]

### Added

- Documentacion nueva en `docs/steamid-reference.md` con la relacion entre `SteamID2`, `SteamID3`, `SteamID64` y `AccountID` basada en la documentacion de Valve.

### Changed

- La validacion de `SteamID64` en el include ahora sigue el rango decimal derivado de la estructura documentada por Valve para cuentas individuales publicas, en vez de depender de prefijos fijos.

### Fixed

- Se corrige el rechazo de `SteamID64` validos que antes quedaban fuera por una heuristica de prefijos demasiado restrictiva.

## [2.3.1]

### Added

- Sistema de debug del plugin con `steamidtools_debug_mask` y comando admin `sm_steamidtools_debug`.
- Trazas utiles para depurar arranque, providers, requests HTTP, health checks y cambios de estado del backend.

### Changed

- El refresco principal del estado del backend ahora se apoya en `OnConfigsExecuted()` y en el resultado de las requests reales.
- `steamidtools_health_check_interval` queda como respaldo opcional; `0` desactiva el timer periodico.
- Las requests online exitosas marcan el backend como `online` y las fallidas como `offline`.

## [2.3.0]

### Added

- API publica de health checks para el backend con:
  - `SteamIDTools_GetBackendStatus`
  - `SteamIDTools_IsProviderReady`
  - `SteamIDTools_RequestHealthCheck`
  - `SteamIDTools_GetBackendStatusMessage`
  - `SteamIDTools_OnBackendStatusChanged`
- Health checks reales a `GET /health` para `SteamWorks` y `system2`.
- Comando de prueba `sm_steamidtools_health <steamworks|system2> [refresh]` en `steamidtools_test.sp`.
- Include compartido `steamidtools_helpers.inc` para reconstruccion de identidades en comandos.

### Changed

- `steamidtools.inc` sube a `2.3.0` y expone el nuevo contrato de estado del backend.
- El plugin cachea el estado `unknown|online|offline` por provider para que otros plugins puedan decidir si el backend esta listo antes de encolar conversiones.

## [2.2.1]

### Fixed

- `steamidtools.inc` ahora declara correctamente el bloque `SharedPlugin` y marca los `natives` del plugin API como opcionales cuando se incluye sin `REQUIRE_PLUGIN`.

## [2.2.0]

### Added

- Plugin API online con `natives` y `forward` para que otros plugins consulten el backend sin implementar transporte HTTP.
- Plugin demo separado para probar la API y mostrar integracion online/offline.

### Changed

- `steamidtools.sp` ahora actua como biblioteca/runtime de SourceMod en vez de registrar comandos de prueba.
- La compilacion y los artefactos incluyen tanto el plugin API como el plugin demo.

## [2.1.0]

### Added

- CI de compilacion y artefactos empaquetados para el plugin.

### Changed

- Requests online comunes desacopladas del transporte y menos codigo duplicado entre `SteamWorks` y `system2`.
- Manejo async mas seguro usando `userid`, URL encoding comun y defaults alineados con el backend.

### Fixed

- Artefacto final sin includes de compilacion exclusivos de CI.

## [2.0.0]

### Added

- Initial tracked release for the SourceMod plugin/include in this repository.
