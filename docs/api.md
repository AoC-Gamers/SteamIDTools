# API local

La API publica son stocks SourcePawn declarados en
`sourcemod/scripting/include/steamidtools_stock.inc`. No hay endpoints HTTP.

Las conversiones enlazan AccountID con SteamID2, SteamID3 y SteamID64. Las
funciones `TryParse` distinguen exito y valor; identidad cero es invalida.
`SteamIDTools_FormatAccountID` imprime valores uint32 sin perder el bit alto.
No convertir SteamID64 a una celda numerica ni usar su formato como autorizacion.

Ver [contratos y pruebas](sourcemod.md) y [migracion](migration.md).
