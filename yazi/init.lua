-- init.lua de yazi SOLO para divvy (se activa con YAZI_CONFIG_HOME).
-- Registra el plugin git.yazi: muestra el estado de git de cada archivo
-- (modificado, nuevo, borrado…) como marca de color en la lista.
require("git"):setup {
	-- Orden de la marca de estado dentro del linemode.
	order = 1500,
}
