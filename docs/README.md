# Documentacion

Esta carpeta concentra la documentacion operativa y tecnica del proyecto.

## Indice

- [Referencia de SteamID](./steamid-reference.md)
- [Inicio Rapido](./getting-started.md)
- [API HTTP](./api.md)
- [Despliegue y Operacion](./deployment.md)
- [Integracion SourceMod](./sourcemod.md)
- [Arquitectura](./architecture.md)

## Referencias Adicionales

- [Changelog Backend Go](../go/CHANGELOG.md)
- [Changelog SourceMod](../sourcemod/CHANGELOG.md)
- [Versionado y Tags](../README.md)

## Componentes

- Backend Go: servicio HTTP para conversiones entre `SteamID64`, `AccountID`, `SteamID2` y `SteamID3`.
- SourceMod: include offline y plugin con implementaciones HTTP para `SteamWorks` y `system2`.
- Swagger/OpenAPI: UI expuesta por el backend en `/swagger/index.html`.

## Referencia conceptual

- [Referencia de SteamID](./steamid-reference.md): definiciones, formulas y relaciones entre `SteamID2`, `SteamID3`, `SteamID64` y `AccountID` basadas en la documentacion de Valve.
