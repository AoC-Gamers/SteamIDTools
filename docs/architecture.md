# Arquitectura

`steamidtools_stock.inc` posee validacion y conversiones puras, con SteamID64
como cadena y AccountID como patron uint32. `steamidtools_helpers.inc` adapta
argumentos de comandos; `steamidtools.inc` es la entrada publica offline.

Cada consumidor compila los stocks que necesita. No existe un runtime central,
transporte de conversiones, timer de health ni biblioteca dinamica SteamIDTools.
La conversion no consulta Steam y no otorga permisos. Los consumidores siguen
siendo responsables de sus controles de autorizacion, SQL y solicitudes de
perfil opcionales a servicios externos.

El ejemplo y el harness son optativos, se compilan fuera del ZIP de producto.
