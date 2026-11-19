# SteamIDTools

- Mantén los includes públicos en `addons/sourcemod/scripting/include/`.
  Conserva los contratos de AccountID uint32, SteamID64 como cadena y retornos
  de búsqueda documentados en [docs/sourcemod.md](docs/sourcemod.md).
- Conserva el núcleo de conversiones independiente de los módulos de clientes
  y comandos. Los consumidores compilan los stocks desde una revisión Git.
- Prepara la toolchain con `make deps-test` y ejecuta `make test` en Linux
  x86_64. El harness de `make build-test-server` se usa para pruebas en SRCDS.
- Las dependencias de prueba van en `.deps/` y las salidas en `.build/`.
  Documenta cambios de consumo en `docs/` y `CHANGELOG.md`.
