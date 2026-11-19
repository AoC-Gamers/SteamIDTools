# Pruebas locales y CI

SteamIDTools se consume desde una revisión Git. Los includes públicos están en
`addons/sourcemod/scripting/include/` y se compilan como parte de cada plugin
consumidor.

## Preparación y ejecución

En Linux x86_64, con Git, Make, un compilador C++ y Python 3 con
`pkg_resources` (`python3-pkg-resources` en Ubuntu 24.04):

```bash
make deps-test
make test
```

`make deps-test` prepara el compilador de SourceMod y construye la VM de
SourcePawn con las revisiones de SourcePawn y AMBuild definidas por el ejecutor.
La descarga de SourceMod selecciona `SOURCEMOD_VERSION` (1.12 por defecto).
La toolchain y el log de su compilación quedan en `.deps/`. Si tu copia
guardaba la toolchain en `deps/`, ejecuta `make deps-test` para preparar la
nueva ruta.

`make test-offline` compila las conversiones y las contrasta con el oráculo en
JIT e intérprete. `make test-modules` verifica los imports del include principal
y prueba los adaptadores de clientes y comandos con entradas modeladas.
CI usa los mismos targets.

`make build-test-server` compila el harness opcional de SRCDS. Ver las
[instrucciones del harness](sourcemod.md#plugin-de-prueba-para-srcds).
Los binarios y el corpus de prueba se generan en `.build/`.
`make clean` limpia estas salidas y conserva la toolchain.
