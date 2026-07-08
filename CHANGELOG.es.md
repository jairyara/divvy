# Registro de cambios

[English](CHANGELOG.md) · **Español**

Aquí se documentan todos los cambios relevantes de divvy.

El formato se basa en [Keep a Changelog](https://keepachangelog.com/es/1.1.0/),
y el proyecto sigue [Versionado Semántico](https://semver.org/lang/es/).

## [1.1.0] - 2026-07-08

### Añadido
- **Modal de git graph (`Alt+g`)** — abre [keifu](https://github.com/trasta298/keifu),
  un TUI del grafo de commits, en un panel flotante sobre el layout; sales con `q`/`Esc`.
  Opcional: el instalador lo pregunta (activo por defecto) y se puede omitir con `--no-keifu`.
- **Estado de git en yazi** — el explorador marca el estado git de cada archivo con una letra
  de color (`?` nuevo · `A` staged · `M` modificado · `D` borrado · `U` conflicto), mediante el
  plugin incluido [`git.yazi`](https://github.com/yazi-rs/plugins/tree/main/git.yazi).
- **Modo zen (`Alt+z`)** — pantalla completa del panel enfocado ocultando el resto; púlsalo de
  nuevo para restaurar el layout.
- **Tool windows** — oculta un panel y deja que el resto reflowee para reclamar el espacio,
  manteniendo su proceso vivo: `Alt+b` archivos · `Alt+a` agente · `Alt+t` terminal. Vuelve a
  mostrarlo con `Alt+Shift+B` / `Alt+Shift+A` / `Alt+Shift+T`.
- **Cambios git en el editor** — las líneas modificadas/añadidas/borradas se marcan en el gutter
  para revisar el diff de un vistazo. En nvim ([gitsigns](https://github.com/lewis6991/gitsigns.nvim))
  navegas con `]h`/`[h`, previsualizas con `<leader>hp` y reviertes un hunk con `<leader>hr` (o todo
  el archivo con `<leader>hR`). helix y micro muestran el gutter de diff de forma nativa.

### Cambiado
- El panel del agente ahora se llama `agent` en el layout (antes tomaba el nombre del comando
  del agente, p. ej. `claude`), para poder targetearlo desde los atajos de tool windows.

## [1.0.0] - 2026-06-25

### Añadido
- Lanzamiento inicial: una terminal dividida sobre **zellij** — archivos
  ([yazi](https://yazi-rs.github.io)) a la izquierda, editor al centro, agente IA a la derecha
  y una terminal abajo.
- **Editores**: nvim (por defecto, abre los archivos de yazi como pestañas vía socket + LSP), helix, micro, vim.
- **Agentes IA**: cualquier comando (`-a`), con claude, codex, opencode, aider, goose y Antigravity sugeridos.
- **Terminales**: corre en cualquier terminal true-color; puede instalar y tematizar Ghostty, WezTerm, kitty, Alacritty.
- **Temas** (`divvy-theme`): dracula, catppuccin, tokyonight, gruvbox, nord — aplicados a todo el stack.
- **Navegación de paneles**: `Alt+1..4` salta directo a archivos/editor/agente/terminal.
- **Instalador guiado** (`install.sh`): multiselección interactiva, detecta brew/apt/dnf/pacman/zypper/apk,
  con fallback a binarios oficiales prebuilt; POSIX `sh`, macOS/Linux (Windows vía WSL2).
- README bilingüe (English · Español).

[1.1.0]: https://github.com/jairyara/divvy/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/jairyara/divvy/releases/tag/v1.0.0
