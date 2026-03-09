# Documentacion

Esta carpeta concentra la documentacion operativa y tecnica del proyecto.

## Indice

- [Inicio Rapido](./getting-started.md)
- [API HTTP](./api.md)
- [Despliegue y Operacion](./deployment.md)
- [Integracion SourceMod](./sourcemod.md)
- [Arquitectura](./architecture.md)

## Referencias Adicionales

- [Changelog General](../CHANGELOG.md)
- [Changelog Backend Go](../go/CHANGELOG.md)
- [Changelog SourceMod](../sourcemod/CHANGELOG.md)

## Componentes

- Backend Go: servicio HTTP para conversiones entre `SteamID64`, `AccountID`, `SteamID2` y `SteamID3`.
- SourceMod: include offline y plugin con implementaciones HTTP para `SteamWorks` y `system2`.
- Swagger/OpenAPI: UI expuesta por el backend en `/swagger/index.html`.
