# Contribuir a divvy

divvy es un puñado de scripts POSIX `sh` que generan un layout de [zellij](https://zellij.dev)
y configuran las herramientas de cada panel. No hay build: editas los scripts y listo.

## Estructura

| Archivo | Rol |
|---|---|
| `divvy` | Lee flags (`-e/-a/-t`) → genera `.runtime/layout.kdl` → lanza zellij |
| `divvy-edit` | Corre el editor central (nvim por socket; resto por FIFO) |
| `divvy-open` | Lo que yazi llama al dar Enter (manda el archivo al editor) |
| `divvy-theme` | Cambia el tema en zellij + ghostty + helix + micro + nvim |
| `install.sh` | Instalador guiado/modular |
| `.config/nvim/` · `helix/` · `micro/` · `vim/` · `yazi/` | Configs aisladas en el repo |

Tras tocar algo, valida sintaxis: `sh -n divvy divvy-edit divvy-open divvy-theme install.sh`.

## Añadir un editor

1. **`divvy`**: agrega el nombre al `case` de validación de `--editor`.
2. **`divvy-edit`**: agrega una rama. Si el editor tiene "remote/socket" (como nvim), úsalo
   para abrir varios archivos en vivo; si no, define `run_editor()` y usará la FIFO (un
   archivo a la vez). Apunta su config a `$DIR/tu-editor/`.
3. **`divvy-open`**: si el editor usa socket, añade su rama; si usa FIFO, ya está cubierto por
   el caso `*`.
4. **`install.sh`**: añade el caso en el `for ed in $SEL_EDITORS` (cmd + paquete brew/pacman).
5. Crea su config en `tu-editor/` con el tema por defecto (dracula).

## Añadir un agente

No hace falta tocar código: `-a` acepta **cualquier comando** en el PATH. Para que aparezca
como recomendado:

1. **`divvy`**: añádelo al texto de `--list` y de la ayuda.
2. **`install.sh`**: añade un caso en `for ag in $SEL_AGENTS` con su método de instalación.
3. **`README.md`**: súmalo a la tabla de [Agentes](README.md#agentes).

## Añadir un tema

1. **`divvy-theme`**: agrega una fila al `case "$THEME"` con el nombre del tema en cada
   herramienta: `Z` (zellij), `G` (ghostty), `H` (helix), `M` (micro).
   - Verifica los nombres exactos:
     - ghostty: `ls "/Applications/Ghostty.app/Contents/Resources/ghostty/themes/"`
     - helix: `ls "$(brew --prefix)"/Cellar/helix/*/libexec/runtime/themes/`
2. **`.config/nvim/init.lua`**: añade la entrada a `MAP` (`cs` = colorscheme, `lualine` = tema
   de la barra) y agrega el plugin del tema en `require("lazy").setup({ ... })`.
3. **`divvy`**: súmalo al `case` de validación de `--theme` y al texto de `--list`.

Consejo: elige variantes con fondos distintos entre sí (ver el set actual en `divvy-theme`)
para que el cambio se note.

## Estilo

- POSIX `sh` (no bashismos): que pase `sh -n`.
- Rutas del proyecto siempre vía el `$DIR` que resuelven los scripts (no hardcodear).
- Mantén las configs **dentro del repo** (no escribir en `~/.config` del usuario salvo zellij
  y ghostty, que son globales por naturaleza).
