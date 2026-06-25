# Contributing to divvy

divvy is a handful of POSIX `sh` scripts that generate a [zellij](https://zellij.dev) layout
and configure the tools in each pane. There's no build step: you edit the scripts and you're
done.

## Structure

| File | Role |
|---|---|
| `divvy` | Reads flags (`-e/-a/-t`) → generates `.runtime/layout.kdl` → launches zellij |
| `divvy-edit` | Runs the center editor (nvim via socket; the rest via FIFO) |
| `divvy-open` | What yazi calls on Enter (sends the file to the editor) |
| `divvy-theme` | Changes the theme across zellij + ghostty + helix + micro + nvim |
| `install.sh` | Guided/modular installer |
| `.config/nvim/` · `helix/` · `micro/` · `vim/` · `yazi/` | Configs isolated in the repo |

After changing anything, validate the syntax: `sh -n divvy divvy-edit divvy-open divvy-theme install.sh`.

## Adding an editor

1. **`divvy`**: add the name to the `--editor` validation `case`.
2. **`divvy-edit`**: add a branch. If the editor has a "remote/socket" (like nvim), use it to
   open several files live; otherwise define `run_editor()` and it will use the FIFO (one file
   at a time). Point its config at `$DIR/your-editor/`.
3. **`divvy-open`**: if the editor uses a socket, add its branch; if it uses a FIFO, the `*`
   case already covers it.
4. **`install.sh`**: add the case in `for ed in $SEL_EDITORS` and a matching `install_<editor>`
   function (package manager first, prebuilt binary as a fallback).
5. Create its config under `your-editor/` with the default theme (dracula).

## Adding an agent

No code change needed: `-a` accepts **any command** on the PATH. To list it as recommended:

1. **`divvy`**: add it to the `--list` text and the help.
2. **`install.sh`**: add a case in `install_agent` with its install method.
3. **`README.md`** / **`README.es.md`**: add it to the [Agents](README.md#agents) table.

## Adding a theme

1. **`divvy-theme`**: add a row to `case "$THEME"` with the theme's name in each tool:
   `Z` (zellij), `G` (ghostty), `H` (helix), `M` (micro).
   - Verify the exact names:
     - ghostty: `ls "/Applications/Ghostty.app/Contents/Resources/ghostty/themes/"`
     - helix: `ls "$(brew --prefix)"/Cellar/helix/*/libexec/runtime/themes/`
2. **`.config/nvim/init.lua`**: add the entry to `MAP` (`cs` = colorscheme, `lualine` = status
   bar theme) and add the theme plugin in `require("lazy").setup({ ... })`.
3. **`divvy`**: add it to the `--theme` validation `case` and to the `--list` text.

Tip: pick variants with backgrounds that differ from each other (see the current set in
`divvy-theme`) so the change is noticeable.

## Style

- POSIX `sh` (no bashisms): it must pass `sh -n`.
- Always reference project paths via the `$DIR` the scripts resolve (don't hardcode).
- Keep configs **inside the repo** (don't write to the user's `~/.config` except for zellij
  and ghostty, which are global by nature).
