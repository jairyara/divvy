-- init.lua de yazi SOLO para divvy (se activa con YAZI_CONFIG_HOME).
-- Registra el plugin git.yazi: muestra el estado de git de cada archivo
-- (modificado, nuevo, borrado…) como marca de color en la lista.
require("git"):setup {
	-- Orden de la marca de estado dentro del linemode.
	order = 1500,
}

-- Plugin zoxide (integrado en yazi): tecla `z` salta a carpetas ya visitadas.
-- update_db = true hace que navegar DENTRO de yazi alimente la base de datos de
-- zoxide, para que `z` tenga adonde saltar aunque nunca uses `cd` en la terminal.
require("zoxide"):setup {
	update_db = true,
}
