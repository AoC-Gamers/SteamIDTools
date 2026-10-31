# Pendientes SteamIDTools

El toolkit offline 3.0.0 usa `addons/sourcemod/scripting/include/`. El backend
anterior permanece en la rama local `codex/archive-http-backend`; `tmp/`
conserva respaldos y evidencia local ignorada por Git. La guia estable esta en
[docs/migration.md](docs/migration.md).

- Aceptacion SRCDS de los consumidores migrados con su propio encargo operativo.
  Ya se copiaron nueve SMX y `sharedplugins.cfg` a competitive_dev, verificando
  hashes y permisos; esa copia no recargo plugins ni ejecuto el CFG.
- Retirada del SMX/CFG HTTP antiguos que sigan instalados y eventual parada de
  un backend desplegado, solo con autorizacion propia. No se realizo esa retirada
  como parte de la copia ni de la limpieza del repositorio.
- Migracion de BanSystem-Legacy si se encarga; conserva su API e includes 2.x.
- Publicacion de repositorios y releases solo cuando se solicite.
