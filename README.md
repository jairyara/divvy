# divvy

**English** · [Español](README.es.md)

![license](https://img.shields.io/badge/license-MIT-blue)
![platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL2-lightgrey)
![shell](https://img.shields.io/badge/shell-POSIX%20sh-89e051)
![built on zellij](https://img.shields.io/badge/built%20on-zellij-orange)
![themes](https://img.shields.io/badge/themes-5-bd93f9)

A split terminal in the style of *tmux/omarchy*, built on **zellij**: a file explorer on the
left, an editor in the center, an AI agent on the right, and a terminal at the bottom — all
with the Dracula theme (plus 4 more swappable themes).

```
┌──────────────────────── tab-bar ────────────────────────┐
│    files      │      editor        │      agent          │
│   (yazi)      │   (nvim/helix/…)   │  (claude/agy/…)     │
├───────────────┴────────────────────┴─────────────────────┤
│   terminal                                                │
├──────────────────────── status-bar ─────────────────────┤
```

Press **Enter** on a file in yazi and it opens in the center editor, with focus jumping
straight to that pane.

---

## Requirements

| Tool | Role | Required |
|---|---|---|
| [zellij](https://zellij.dev) | Multiplexer (splits the screen) | ✅ |
| [yazi](https://yazi-rs.github.io) | File explorer (left pane) | ✅ |
| nvim / helix / micro / vim | Editor (center pane) | at least one |
| an AI agent (CLI) | Right pane — see [Agents](#agents) | at least one |
| [Ghostty](https://ghostty.org) | Terminal with *true color* (recommended) | optional |
| JetBrainsMono Nerd Font | Icons in yazi/lualine | optional |

> **Terminal:** it works in any terminal, but for the themes to look right you need
> *true color*. Apple Terminal only gives 256 colors — use **Ghostty**, WezTerm, or Alacritty.

---

## Installation

```sh
git clone <your-repo> ~/divvy
cd ~/divvy
./install.sh          # guided: you pick what to install (not everything)
```

The installer is **interactive**: the core (zellij + yazi) is required, and you choose
editors, terminal (Ghostty), font, and agents with a checkbox menu (**space** to toggle,
**↑/↓** to move, **Enter** to confirm). It detects what's already installed and skips it.

It tries your system package manager first — **brew** (macOS/Linux), **apt**, **dnf**,
**pacman**, **zypper**, or **apk**. If a tool isn't packaged for your system, it downloads the
official prebuilt binary into `~/.local/bin`, so you never have to install things by hand.

**No prompts (flags):**

```sh
./install.sh --minimal                 # core + nvim, nothing else
./install.sh --all                     # everything
./install.sh --editors "helix nvim" --agents "codex gemini" --no-ghostty --yes
./install.sh --dry-run                 # show what it would do, without installing
BINDIR=/usr/local/bin ./install.sh     # change where the symlinks go
```

| Flag | What it does |
|---|---|
| `--minimal` | core + nvim only |
| `--all` | editors, Ghostty, font, and agents |
| `--editors "..."` | list of editors (nvim helix micro vim) |
| `--agents "..."` | agents to install (codex gemini opencode aider goose) |
| `--no-ghostty` / `--no-font` | skip Ghostty / the font |
| `--yes` | no confirmation · `--dry-run` simulates |

---

## Usage

```sh
divvy                              # nvim + claude (defaults)
divvy -e helix -a agy             # helix + antigravity
divvy --editor micro --agent claude
divvy --theme nord                 # set theme and launch
divvy --list                       # show editors, agents, and themes
divvy --help
```

> **nvim is the default editor**: it runs as a server, so every file you open from yazi piles
> up as a **tab** (bufferline). It ships with LSP and doesn't clash with zellij (`:w` to save,
> `:q` to close). helix/micro/vim open one file at a time (no socket) → `-e helix`.

### Flags

| Flag | Values | Default |
|---|---|---|
| `-e`, `--editor` | `nvim` · `helix` · `micro` · `vim` | `nvim` |
| `-a`, `--agent`  | any command (see [Agents](#agents)) | `claude` |
| `-t`, `--theme`  | `dracula` · `catppuccin` · `tokyonight` · `gruvbox` · `nord` | — |
| `--dry-run` | generate the layout and print it (don't launch) | |
| `-l`, `--list` / `-h`, `--help` | | |

---

## Themes

They change the **whole stack at once** (zellij + ghostty + helix + micro + nvim):

```sh
divvy-theme nord          # just change the theme
divvy --theme nord        # change and launch
```

Themes: `dracula` · `catppuccin` · `tokyonight` · `gruvbox` · `nord`.

> After changing the theme: **relaunch divvy** (zellij/editors) and in **Ghostty** press
> `Cmd+Shift+R` to reload the theme without restarting.

---

## Agents

The right pane runs **any command** you pass with `-a`, so you can use whichever agent you
prefer (and pay for). Suggested ones:

| Agent | `-a` | Install |
|---|---|---|
| Claude Code | `claude` | `npm i -g @anthropic-ai/claude-code` · `curl -fsSL https://claude.ai/install.sh \| sh` |
| OpenAI Codex | `codex` | `brew install --cask codex` · `npm i -g @openai/codex` |
| Gemini CLI | `gemini` | `brew install gemini-cli` · `npm i -g @google/gemini-cli` |
| opencode | `opencode` | `brew install opencode` · `npm i -g opencode-ai` |
| aider | `aider` | `brew install aider` · `pipx install aider-chat` |
| goose | `goose` | `brew install block-goose-cli` |
| Antigravity | `agy` | `curl -fsSL https://antigravity.google/cli/install.sh \| sh` |

```sh
divvy -a codex          # OpenAI Codex
divvy -a gemini         # Gemini
divvy -a my-agent       # any command of yours
```

If the command isn't installed, divvy warns you and the pane shows the error (it doesn't break
the rest).

## Shortcuts (zellij)

| Action | Key |
|---|---|
| Jump to a specific pane | `Alt` + `1` files · `2` editor · `3` agent · `4` terminal (recommended) |
| Move between panes | `Alt` + arrows · `Alt` + `h/j/k/l` |
| Fullscreen the pane | `Ctrl p` → `f` |
| New tab | `Ctrl t` → `n` · switch: `Ctrl t` → arrows |
| Scroll mode (see old output) | `Ctrl s` (exit with `Esc`) |
| Resize pane | `Ctrl n` → arrows |
| Quit | `Ctrl q` |

In **yazi** (left pane): `↑/↓` navigate, `→` enter, `←` go up, `Enter` open in the editor.

---

## How it works

| Script | Role |
|---|---|
| `divvy` | Reads the flags → generates `.runtime/layout.kdl` → launches zellij |
| `divvy-edit` | Runs the center editor |
| `divvy-open` | What yazi calls on Enter (sends the file to the editor) |
| `divvy-theme` | Changes the theme across all tools |

**yazi → editor integration:**
- **nvim**: starts as a server (`--listen`); yazi sends files over a socket → they open as
  buffers, live. *The smoothest one.* Includes **LSP** (completion, go-to-definition,
  diagnostics via mason) + treesitter + theme.
- **helix / micro / vim**: no socket; yazi sends the path over a FIFO. You open a file and
  edit it; to open another one from yazi, **close the current one** first. (helix ships with
  built-in LSP.)

Only **text/code** goes to the editor; images, PDFs, and video open with the system app.
Sockets/FIFOs are named per zellij session, so you can run **several divvy windows at once**
without them stepping on each other.

### Shortcuts in nvim (the default editor)

| Action | Key |
|---|---|
| Next / previous tab | `Tab` / `Shift+Tab` |
| Close tab | `:q` or `<leader>x` (leader = space) — does **not** close nvim |
| Save and close tab | `:wq` |
| Quit nvim entirely | `:qa` (or `:q!` to force) |
| Go to definition / references | `gd` / `gr` |
| Documentation | `K` |
| Rename / code action | `<leader>rn` / `<leader>ca` |
| Jump between errors | `[d` / `]d` |
| Completion | `Ctrl-space` (accept with `Ctrl-y`) |

Configs (all inside the project, they don't touch your `~/.config`):
`.config/nvim/init.lua` · `helix/config.toml` · `micro/settings.json` · `vim/vimrc` · `yazi/yazi.toml`.

---

## Portability

| OS | Status |
|---|---|
| macOS | ✅ |
| Linux | ✅ (installer and symlink path change; the script adapts itself) |
| Windows | ⚠️ only via **WSL2** (zellij/Ghostty aren't native to Windows) |

---

## Common issues

- **Weird colors:** your terminal lacks true color → use Ghostty/WezTerm/Alacritty.
- **`Alt`+arrows don't move focus:** in Apple Terminal enable "Use Option as Meta"; in Ghostty
  it's already on (`macos-option-as-alt`).
- **`Ctrl`+`1..4` doesn't jump panes:** most terminals don't send `Ctrl`+number uniquely
  (`Ctrl+2`=NUL, `Ctrl+3`=ESC…). Use **`Alt`+`1..4`**, which is reliable.
- **A file opened from yazi doesn't show up / yazi "hangs" on Enter:** this was a modal nvim
  prompt (swap file or "Press ENTER") freezing the server. It's mitigated now; if it comes
  back, run `divvy-clean` and relaunch `divvy`.
- **Icons show as boxes:** install a Nerd Font and select it in your terminal.
- **The agent pane shows an error:** that agent isn't installed (`opencode` isn't there by
  default).
- **micro: `Ctrl+S`/`Ctrl+Q` don't work** (zellij captures them: search and quit). Before
  editing, press `Ctrl+g` (locks zellij → all keys go to micro), save/close normally, then
  `Ctrl+g` again to navigate.

---

## License

[MIT](LICENSE) © 2026 Jair Yara
