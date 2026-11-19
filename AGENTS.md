# SteamIDTools

- Mantén los includes públicos en `addons/sourcemod/scripting/include/`.
  Conserva los contratos de AccountID uint32, SteamID64 como cadena y retornos
  de búsqueda documentados en [docs/sourcemod.md](docs/sourcemod.md).
- Conserva el núcleo de conversiones independiente de los módulos de clientes
  y comandos. Los consumidores compilan los stocks desde una revisión Git.
- Valida los cambios de los includes compilando los plugins consumidores
  que usan los módulos afectados.
- Documenta cambios de consumo en `docs/` y `CHANGELOG.md`.
