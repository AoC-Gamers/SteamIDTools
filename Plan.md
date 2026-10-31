# Transicion a conversiones offline

## Objetivo y alcance

Convertir SteamIDTools en una biblioteca SourcePawn de conversiones locales,
sin backend Go, transporte HTTP ni plugin residente obligatorio. Esta propuesta
no autoriza publicacion, despliegue, copia de binarios, carga de plugins ni
operacion de servidores. Todos los pasos siguientes estan pendientes.

## 1. Conservar el estado anterior

- Antes de implementar, revisar de nuevo el estado de Git y crear una rama local
  propuesta `codex/archive-http-backend` en el commit previo a la retirada.
  El punto inspeccionado es `b241bdae108826a4230a7f3901472c53d4cba595`, en
  `develop`, con el arbol de archivos versionados limpio antes de este plan.
- Si hay nuevos cambios de producto, preservar primero su estado en un commit
  revisado y usar ese commit como referencia. No incluir secretos, `.env`, caches
  ni artefactos ignorados. Una rama conserva archivos versionados, no recursos
  externos ni instalaciones en ejecucion.
- Verificar que la rama conserva Go, Docker, API HTTP, providers SourceMod,
  workflows y documentacion actuales. Continuar la retirada en `develop`, sin
  publicar la rama de conservacion ni reescribir historia.

## 2. Migrar consumidores antes de retirar la API

- Inventariar usos reales, includes que importan natives y copias distribuidas.
  No basta con que un consumidor no llame HTTP en su flujo habitual.
- `L4D2-Family-Share`: retirar la conversion online opcional de perfiles y usar
  la identidad calculada localmente desde AccountID. Eliminar solo el contexto,
  ConVar y seguimiento de biblioteca asociados a esa conversion. Conservar las
  consultas Steam Web API para perfiles, sus deadlines, handles y callbacks.
  SteamWorks sigue siendo necesario para esas consultas.
- `CallVote-Manager`: `callvote_bans/helpers.sp` solicita `SID64toAID` online.
  Sustituirlo por el parser offline validado, preservando permisos, validacion
  de identidad, inmunidad, acciones y respuestas. Comprobar todos sus entrypoints
  aunque ese satelite no figure entre los plugins activos de AoC.
- `BanSystem-Sourcepawn`: revisar imports y callbacks online residuales en Access,
  Comm, Sprays y CallVotes; no se encontraron llamadas a los natives de request
  en sus fuentes actuales. Conservar la resolucion local y todos los controles
  de autorizacion/enforcement. Retirar contextos muertos solo tras verificar
  referencias, cleanup y pruebas de cada dominio.
- Las fuentes de `BanSystem-Legacy` tambien llaman la API online. Documentar que
  esa version requiere el SteamIDTools conservado; no modernizar Legacy como
  efecto secundario. No distribuirle el nuevo include sin migracion explicita.
- Actualizar las copias de includes en los repositorios activos y comprobar su
  procedencia. Preservar cambios ajenos y separar commits por repositorio.

## 3. Hacer del include offline el producto principal

- Mantener `steamidtools_stock.inc` y `steamidtools_helpers.inc`, sus nombres
  publicos y contratos de validacion. Convertir `steamidtools.inc` en una entrada
  comoda al toolkit offline, sin `SharedPlugin`, natives, forwards ni providers.
- Conservar SteamID64 como cadena y AccountID como patron uint32 en una celda
  SourcePawn; no rechazar el bit alto ni usar `accountId > 0` como validacion.
  Mantener rechazo de cero como identidad, overflow, texto sobrante y buffers
  insuficientes, sin alterar las salidas cuando el contrato asi lo establece.
- Eliminar el plugin API `steamidtools.sp` y sus modulos HTTP. Los stocks se
  compilan dentro de cada consumidor y no necesitan un SMX residente.
- Adaptar el ejemplo a conversiones locales como opcion predeterminada, sin
  seleccionar provider ni health checks. Mantenerlo fuera del paquete ordinario;
  conservar el harness de regresion separado para pruebas optativas.
- Tratar la retirada de la API online como cambio incompatible: proponer
  SourceMod `3.0.0`, con guia de migracion, en vez de simular respuestas HTTP o
  callbacks antiguos mediante stubs.

## 4. Retirar backend, empaquetado e integracion obsoletos

- Retirar `go/`, Dockerfile, Compose, plantilla de entorno y herramientas
  exclusivas de Go, Swagger, health HTTP y publicacion de imagenes.
- Simplificar Makefile, workflows y resolucion de releases para SourcePawn.
  Mantener build Linux, pruebas offline, validacion de artifact y ZIP de includes
  sin exigir que exista un SMX de produccion. No publicar ni borrar imagenes,
  releases o tags existentes como parte de esta tarea.
- Revisar `plugin-package-map.json`, build, staging y validadores: actualmente
  esperan `custom/steamidtools.smx`. Permitir el paquete de includes y excluir
  providers, includes de System2/SteamWorks y fuentes HTTP retiradas.
- Reescribir README, indice y documentos canonicos para instalacion offline,
  conversiones, pruebas y migracion. Mantener la referencia conceptual de SteamID.
- En AoC, retirar la carga de `custom/steamidtools.smx` de `sharedplugins.cfg` y
  el CFG que configura URL, health y debug del backend. En Docker-L4D2-AoC,
  adaptar el hook/manifiesto a un componente de includes o retirarlo si queda
  redundante con el empaquetado de los consumidores. Verificar primero el flujo
  real de instalacion. No desinstalar extensiones compartidas globalmente.
- Documentar la retirada futura del SMX antiguo de instalaciones existentes:
  quitarlo del paquete no elimina por si solo el binario que ya este instalado.
  No efectuar esa retirada ni detener un backend en ejecucion durante este trabajo.

## 5. Validacion aislada y cierre

- Ejecutar la suite actual con `make test-offline`: include productivo en JIT e
  interprete, oraculo Python, 12 casos de borde y 2.048 AccountIDs reproducibles.
  Preparar la VM solo si falta, segun `docs/sourcemod.md`.
- Conservar y ampliar casos de entradas invalidas, limites uint32, conversiones
  inversas y buffers. Probar tambien que importar `steamidtools.inc` no incorpora
  dependencias de plugin ni de extensiones.
- Ejecutar `make deps-smx` y el build adaptado; compilar el ejemplo y harness
  aunque no formen parte del paquete. Compilar los consumidores migrados con los
  nuevos includes y ejecutar sus regresiones apropiadas en aislamiento.
- Validar el ZIP y la instalacion en un directorio temporal: includes presentes,
  ningun SMX HTTP, ninguna referencia activa a System2/backend y ninguna carga
  obsoleta en la configuracion AoC. Revisar CI sin ejecutarlo remotamente.
- Revisar diff y enlaces de documentacion. Registrar solo resultados realmente
  ejecutados. Guardar cambios en commits locales por repositorio cuando se
  autorice implementar; la aceptacion en servidor permanece separada.

## Evidencia de esta planificacion

Se leyeron fuentes, API publica, documentacion, build, release y consumidores
locales. No se ejecutaron pruebas de conversion, compilaciones ni operaciones
de servidor. No se creo aun la rama de conservacion ni se retiro codigo.
