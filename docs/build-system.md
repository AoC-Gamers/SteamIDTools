# Build y empaquetado

Las fuentes publicas viven en `addons/sourcemod/scripting/include/` y el
changelog en `CHANGELOG.md`. `plugin-package-map.json` declara exclusivamente
el principal y los dos modulos distribuidos; no existe una lista de plugins de produccion.

`make build-smx` prepara esos includes en `.build/smx/addons/sourcemod/scripting/include/`
y escribe `deps/build-toolkit.log`. Este target conserva el nombre homologado
del resto de repositorios, pero no compila ni requiere un SMX ni SDK.
`make package-smx` prepara `.build/package-smx`; `make release-smx` genera el ZIP
en `dist/release/` con includes, documentacion, changelog y `build.log`.

`scripts/ci-validate-artifact.sh` verifica archivos declarados, contenido exacto
y ausencia de extras. `make check-package` valida facade, aislamiento, ZIP y
enlaces. El paquete no contiene plugins, extensiones ni harnesses.

## Pruebas aisladas

El compilador y la VM se necesitan para pruebas, no para preparar los includes:

```bash
make deps-smx
python3 scripts/test-sourcepawn-offline.py --prepare-vm
make test-offline
make build-smx package-smx release-smx check-package
```

`make test-offline` compila el stock real y lo ejecuta con JIT e interprete.
`make check-package` compila y ejecuta la fachada publica y comprueba sus imports.
El harness opcional de servidor se compila con
`python3 scripts/test-sourcepawn-offline.py --server-plugin`; no se instala ni
se ejecuta automaticamente. Ninguna de estas validaciones opera SRCDS.

## Archivos locales

Usar `tmp/` dentro del repositorio para logs, respaldos y fixtures temporales.
Esta carpeta esta ignorada por Git y no se distribuye en el ZIP. `make clean`
limpia `.build/` y `dist/`; conserva `tmp/`, las dependencias y la VM.

`make check-package` ejecuta tambien los modulos productivos de clientes y
comandos en JIT e interprete, con entradas de engine/consola modeladas. Cubre
uint32, no conectado/invalido, normalizacion y reconstruccion de argumentos;
no acredita comportamiento real de clientes o consola de SRCDS.
