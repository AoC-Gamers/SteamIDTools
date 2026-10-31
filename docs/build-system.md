# Build y empaquetado

`make deps-smx` prepara SourceMod Linux. `make build-smx` compila `examples/steamidtools_example.sp` en
`.build/examples/`, registra el compilador en `deps/build-smx-compile.log` y
materializa solo los tres includes en `.build/smx/addons/sourcemod/scripting/include/`.
`plugin-package-map.json` declara un conjunto vacio de plugins de produccion.

`make package-smx` prepara `.build/package-smx`; `make release-smx` genera el ZIP
en `dist/release/`. `scripts/ci-validate-artifact.sh` valida el arbol preparado
por `scripts/stage-artifact.py`; `make check-package` comprueba aislamiento y
contratos del artifact. El paquete excluye plugins, providers y pruebas.

`make test-offline` ejecuta los stocks productivos en JIT e interprete.
Preparar una vez la VM con
`python3 scripts/test-sourcepawn-offline.py --prepare-vm`.
No se compila ni publica un backend. Los workflows de SourceMod y release
validan el toolkit; publicar sigue requiriendo autorizacion del usuario.

## Archivos locales

Usar `tmp/` dentro del repositorio para logs, respaldos y fixtures temporales.
Esta carpeta esta ignorada por Git y no se distribuye en el ZIP. `make clean`
limpia `.build/` y `dist/`; conserva `tmp/`, las dependencias y la VM.
