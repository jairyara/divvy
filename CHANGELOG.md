# Changelog

**English** · [Español](CHANGELOG.es.md)

All notable changes to divvy are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-07-08

### Added
- **Git graph modal (`Alt+g`)** — opens [keifu](https://github.com/trasta298/keifu),
  a git commit-graph TUI, in a floating pane on top of the layout; quit it with `q`/`Esc`.
  Optional: the installer asks (on by default), and it can be skipped with `--no-keifu`.
- **Git status in yazi** — the file explorer marks each file's git state with a colored
  letter (`?` new · `A` staged · `M` modified · `D` deleted · `U` conflict), via the
  bundled [`git.yazi`](https://github.com/yazi-rs/plugins/tree/main/git.yazi) plugin.
- **Zen mode (`Alt+z`)** — fullscreen the focused pane and hide the rest; press again to
  restore the layout.
- **Tool windows** — hide a pane and let the rest reflow to reclaim the space, keeping its
  process alive: `Alt+b` files · `Alt+a` agent · `Alt+t` terminal. Bring it back with
  `Alt+Shift+B` / `Alt+Shift+A` / `Alt+Shift+T`.

### Changed
- The agent pane is now named `agent` in the layout (previously it took the agent command's
  name, e.g. `claude`), so it can be targeted by the tool-window shortcuts.

## [1.0.0] - 2026-06-25

### Added
- Initial release: a split terminal built on **zellij** — files ([yazi](https://yazi-rs.github.io))
  on the left, an editor in the center, an AI agent on the right, and a terminal at the bottom.
- **Editors**: nvim (default, opens files from yazi as tabs over a socket + LSP), helix, micro, vim.
- **AI agents**: any command (`-a`), with claude, codex, opencode, aider, goose and Antigravity suggested.
- **Terminals**: runs in any true-color terminal; can install and auto-theme Ghostty, WezTerm, kitty, Alacritty.
- **Themes** (`divvy-theme`): dracula, catppuccin, tokyonight, gruvbox, nord — applied across the whole stack.
- **Pane navigation**: `Alt+1..4` jump straight to files/editor/agent/terminal.
- **Guided installer** (`install.sh`): interactive multi-select, detects brew/apt/dnf/pacman/zypper/apk,
  falls back to official prebuilt binaries; POSIX `sh`, macOS/Linux (Windows via WSL2).
- Bilingual README (English · Español).

[1.1.0]: https://github.com/jairyara/divvy/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/jairyara/divvy/releases/tag/v1.0.0
