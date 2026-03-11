# SourceMod Changelog

Este archivo sigue el formato de Keep a Changelog y usa SemVer.

## [Unreleased]

### Added

- None.

### Changed

- None.

### Fixed

- None.

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
