# Pendientes SteamIDTools

El toolkit offline 4.0.0 usa `addons/sourcemod/scripting/include/`. El backend
anterior permanece en la rama local `codex/archive-http-backend`; `tmp/`
conserva respaldos y evidencia local ignorada por Git. La guia estable esta en
[docs/migration.md](docs/migration.md).

- Aceptacion SRCDS del recorrido offline con su propio encargo operativo.
  En la migracion offline 3.x se copiaron nueve SMX y `sharedplugins.cfg` a competitive_dev, verificando
  hashes y permisos; esa copia no recargo plugins ni ejecuto el CFG.
- Aceptacion instalada del layout modular 4.x cuando se autorice su entrega.
  La retirada del antiguo steamidtools.smx y su CFG de competitive_dev ya se
  realizo con respaldo, sin descargar/recargar plugins ni reiniciar el servidor.
- Eventual parada de un backend desplegado, solo con autorizacion propia.
- Migracion de BanSystem-Legacy si se encarga; conserva su API e includes 2.x.
- Publicacion de repositorios y releases solo cuando se solicite.
