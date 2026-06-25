#!/bin/sh
# install.sh — guided installer for divvy (macOS / Linux).
# Interactive by default: you choose what to install. It also accepts flags.
#
# Usage:
#   ./install.sh                      # guided (asks questions)
#   ./install.sh --all                # everything (editors, Ghostty, font, brew agents)
#   ./install.sh --minimal            # core + nvim, nothing else
#   ./install.sh --editors "nvim helix" --agents "codex gemini" --no-ghostty --yes
#   BINDIR=/usr/local/bin ./install.sh
#
# It tries your system package manager first (brew, apt, dnf, pacman, zypper, apk).
# If a tool isn't packaged for your system, it downloads the official prebuilt
# binary into ~/.local/bin so you don't have to install anything by hand.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
BINDIR="${BINDIR:-$HOME/.local/bin}"
OS="$(uname -s)"
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64)  ARCH=x86_64 ;;
    aarch64|arm64) ARCH=aarch64 ;;
esac

# ─────────────── pretty output ───────────────
say()  { printf '\033[1;35m==>\033[0m %s\n' "$1"; }      # step
ok()   { printf '\033[1;32m  ✓\033[0m %s\n' "$1"; }      # success
warn() { printf '\033[1;33m  !\033[0m %s\n' "$1"; }      # warning / manual step
info() { printf '    %s\n' "$1"; }                       # extra detail
head() { printf '\n\033[1;36m%s\033[0m\n' "$1"; }        # section title

have() { command -v "$1" >/dev/null 2>&1; }              # is command available?

# ─────────────── selection (defaults) ───────────────
SEL_EDITORS="nvim"           # nvim helix micro vim (nvim = default)
WANT_GHOSTTY=ask             # ask|1|0
WANT_FONT=ask
SEL_AGENTS=""                # codex gemini opencode aider goose
ASSUME_YES=0
DRY_RUN=0
INTERACTIVE=1

# ─────────────── flags ───────────────
while [ $# -gt 0 ]; do
    case "$1" in
        --all)      SEL_EDITORS="nvim helix micro vim"; WANT_GHOSTTY=1; WANT_FONT=1;
                    SEL_AGENTS="codex gemini opencode aider goose"; INTERACTIVE=0; shift ;;
        --minimal)  SEL_EDITORS="nvim"; WANT_GHOSTTY=0; WANT_FONT=0; SEL_AGENTS=""; INTERACTIVE=0; shift ;;
        --editors)  SEL_EDITORS="$2"; INTERACTIVE=0; shift 2 ;;
        --agents)   SEL_AGENTS="$2"; INTERACTIVE=0; shift 2 ;;
        --no-ghostty) WANT_GHOSTTY=0; INTERACTIVE=0; shift ;;
        --ghostty)    WANT_GHOSTTY=1; INTERACTIVE=0; shift ;;
        --no-font)    WANT_FONT=0; INTERACTIVE=0; shift ;;
        --font)       WANT_FONT=1; INTERACTIVE=0; shift ;;
        --yes|-y)     ASSUME_YES=1; INTERACTIVE=0; shift ;;
        --dry-run)    DRY_RUN=1; shift ;;
        -h|--help)
            sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) warn "Unknown option: $1"; exit 1 ;;
    esac
done
[ -t 0 ] || INTERACTIVE=0    # no interactive terminal → don't ask

# ─────────────── package manager ───────────────
# Detect the system package manager and whether we need sudo for it.
PM=none; SUDO=""
if   have brew;    then PM=brew
elif have apt-get; then PM=apt
elif have dnf;     then PM=dnf
elif have pacman;  then PM=pacman
elif have zypper;  then PM=zypper
elif have apk;     then PM=apk
fi
# brew never uses sudo; the others do when we aren't root.
if [ "$PM" != brew ] && [ "$PM" != none ] && [ "$(id -u)" != 0 ] && have sudo; then
    SUDO=sudo
fi

# Install one or more packages with the detected manager (same name across distros).
pm_install() {
    [ "$DRY_RUN" = 1 ] && { info "[dry-run] $PM install $*"; return 0; }
    case "$PM" in
        brew)   brew install "$@" ;;
        apt)    $SUDO apt-get update -qq && $SUDO apt-get install -y "$@" ;;
        dnf)    $SUDO dnf install -y "$@" ;;
        pacman) $SUDO pacman -S --needed --noconfirm "$@" ;;
        zypper) $SUDO zypper install -y "$@" ;;
        apk)    $SUDO apk add "$@" ;;
        none)   return 1 ;;
    esac
}

# Make sure a helper tool (tar, unzip, xz…) is present; install it quietly if not.
need() { have "$1" || pm_install "$1" >/dev/null 2>&1 || warn "missing '$1' — install it and re-run"; }

# Download a URL to a file using curl or wget, whichever exists.
fetch() {
    if   have curl; then curl -fsSL "$1" -o "$2"
    elif have wget; then wget -qO "$2" "$1"
    else warn "need 'curl' or 'wget' to download files"; return 1; fi
}

# Print the download URL of the latest GitHub release asset matching a substring.
#   gh_asset <owner/repo> <substring>
gh_asset() {
    _api="https://api.github.com/repos/$1/releases/latest"
    if   have curl; then _json=$(curl -fsSL "$_api" 2>/dev/null)
    elif have wget; then _json=$(wget -qO- "$_api" 2>/dev/null)
    else return 1; fi
    printf '%s\n' "$_json" \
        | grep -o '"browser_download_url": *"[^"]*"' \
        | sed 's/.*"\(http[^"]*\)".*/\1/' \
        | grep "$2" | head -1
}

# ─────────────── interactive multi-select ───────────────
# Checkbox menu. Space toggles, ↑/↓ or j/k move, Enter confirms.
#   multiselect "Title (one line)" RESULT_VAR "opt1 opt2 opt3" "preselected"
# Leaves the chosen options (in option order) in RESULT_VAR.
multiselect() {
    _ms_title="$1"; _ms_var="$2"; _ms_opts="$3"; _ms_sel=" $4 "
    _ms_n=0; for _o in $_ms_opts; do _ms_n=$((_ms_n+1)); done
    _ms_cur=0
    _ms_esc=$(printf '\033')

    _ms_old=$(stty -g 2>/dev/null)
    trap 'stty "$_ms_old" 2>/dev/null; printf "\033[?25h\n"; exit 130' INT
    stty -echo -icanon min 1 time 0 2>/dev/null
    printf '\033[?25l'   # hide cursor

    _ms_first=1
    while :; do
        [ "$_ms_first" = 1 ] && _ms_first=0 || printf '\033[%dA' $((_ms_n+1))
        printf '\r\033[K\033[1;36m%s\033[0m\n' "$_ms_title"
        _i=0
        for _o in $_ms_opts; do
            if [ "$_i" = "$_ms_cur" ]; then _ptr='\033[1;36m❯\033[0m'; else _ptr=' '; fi
            case "$_ms_sel" in *" $_o "*) _box='\033[1;32m[x]\033[0m';; *) _box='[ ]';; esac
            printf '\r\033[K %b %b  %s\n' "$_ptr" "$_box" "$_o"
            _i=$((_i+1))
        done

        _k=$(dd bs=1 count=1 2>/dev/null)
        if [ "$_k" = "$_ms_esc" ]; then           # arrow sequence: ESC [ A/B
            dd bs=1 count=1 2>/dev/null >/dev/null # consume '['
            _k=$(dd bs=1 count=1 2>/dev/null)
            case "$_k" in A) _k=k;; B) _k=j;; *) _k=;; esac
        fi
        case "$_k" in
            '') break ;;                           # Enter → confirm
            ' ')                                    # toggle option under the cursor
                _i=0
                for _o in $_ms_opts; do
                    if [ "$_i" = "$_ms_cur" ]; then
                        case "$_ms_sel" in
                            *" $_o "*) _ms_sel=$(printf '%s' "$_ms_sel" | sed "s/ $_o / /") ;;
                            *)         _ms_sel="$_ms_sel$_o " ;;
                        esac
                        break
                    fi
                    _i=$((_i+1))
                done ;;
            k) [ "$_ms_cur" -gt 0 ] && _ms_cur=$((_ms_cur-1)) || _ms_cur=$((_ms_n-1)) ;;
            j) [ "$_ms_cur" -lt $((_ms_n-1)) ] && _ms_cur=$((_ms_cur+1)) || _ms_cur=0 ;;
        esac
    done

    stty "$_ms_old" 2>/dev/null
    printf '\033[?25h'   # show cursor
    trap - INT

    _ms_res=""
    for _o in $_ms_opts; do
        case "$_ms_sel" in *" $_o "*) _ms_res="$_ms_res $_o";; esac
    done
    _ms_res=$(printf '%s' "$_ms_res" | sed 's/^ *//;s/ *$//')
    eval "$_ms_var=\"\$_ms_res\""
}

# Yes/No prompt. Returns 0 for yes, 1 for no.
ask_yn() {
    _def="$2"
    if [ "$INTERACTIVE" = 0 ]; then [ "$_def" = y ] && return 0 || return 1; fi
    _hint="[y/N]"; [ "$_def" = y ] && _hint="[Y/n]"
    printf "%s %s: " "$1" "$_hint"; read _a 2>/dev/null || _a=""
    [ -z "$_a" ] && _a="$_def"
    case "$_a" in y|Y|yes|s|S|si) return 0 ;; *) return 1 ;; esac
}

# ─────────────── per-tool installers ───────────────
# Each function installs one tool. It tries the package manager first, then a
# prebuilt binary download as a fallback. Returns 0 on success.

install_zellij() {
    case "$PM" in brew|pacman) pm_install zellij && return 0 ;; esac
    have cargo && { say "Building zellij with cargo (this can take a while)…"; cargo install zellij && return 0; }
    need tar
    _u=$(gh_asset zellij-org/zellij "zellij-$ARCH-unknown-linux-musl.tar.gz")
    [ -n "$_u" ] || return 1
    _t=$(mktemp -d); fetch "$_u" "$_t/z.tgz" && tar -xzf "$_t/z.tgz" -C "$_t" || { rm -rf "$_t"; return 1; }
    mkdir -p "$BINDIR"; install -m 0755 "$_t/zellij" "$BINDIR/zellij"; rm -rf "$_t"
}

install_yazi() {
    case "$PM" in brew|pacman) pm_install yazi && return 0 ;; esac
    have cargo && { say "Building yazi with cargo (this can take a while)…"; cargo install --locked yazi-fm yazi-cli && return 0; }
    need unzip
    _u=$(gh_asset sxyazi/yazi "yazi-$ARCH-unknown-linux-musl.zip")
    [ -n "$_u" ] || return 1
    _t=$(mktemp -d); fetch "$_u" "$_t/y.zip" && unzip -q "$_t/y.zip" -d "$_t" || { rm -rf "$_t"; return 1; }
    _d=$(find "$_t" -maxdepth 1 -type d -name 'yazi-*' | head -1)
    mkdir -p "$BINDIR"
    install -m 0755 "$_d/yazi" "$BINDIR/yazi"
    [ -f "$_d/ya" ] && install -m 0755 "$_d/ya" "$BINDIR/ya"
    rm -rf "$_t"
}

install_helix() {
    case "$PM" in brew|pacman) pm_install helix && return 0 ;; esac
    need tar; need xz
    _u=$(gh_asset helix-editor/helix "$ARCH-linux.tar.xz")
    [ -n "$_u" ] || return 1
    _t=$(mktemp -d); fetch "$_u" "$_t/h.txz" && tar -xJf "$_t/h.txz" -C "$_t" || { rm -rf "$_t"; return 1; }
    _d=$(find "$_t" -maxdepth 1 -type d -name 'helix-*' | head -1)
    mkdir -p "$BINDIR"; install -m 0755 "$_d/hx" "$BINDIR/hx"
    # Helix needs its runtime directory next to the binary or in ~/.config/helix.
    mkdir -p "$HOME/.config/helix"; rm -rf "$HOME/.config/helix/runtime"
    cp -r "$_d/runtime" "$HOME/.config/helix/runtime"
    rm -rf "$_t"
}

install_nvim() {
    case "$PM" in brew) pm_install neovim && return 0 ;; esac
    need tar
    case "$ARCH" in x86_64) _a=linux-x86_64 ;; aarch64) _a=linux-arm64 ;; *) _a=linux64 ;; esac
    _u=""
    for _pat in "nvim-$_a.tar.gz" "nvim-linux64.tar.gz"; do
        _u=$(gh_asset neovim/neovim "$_pat"); [ -n "$_u" ] && break
    done
    if [ -n "$_u" ]; then
        _t=$(mktemp -d); fetch "$_u" "$_t/n.tgz" && tar -xzf "$_t/n.tgz" -C "$_t" || { rm -rf "$_t"; return 1; }
        _d=$(find "$_t" -maxdepth 1 -type d -name 'nvim-*' | head -1)
        rm -rf "$HOME/.local/share/divvy-nvim"; mkdir -p "$HOME/.local/share"
        cp -r "$_d" "$HOME/.local/share/divvy-nvim"
        mkdir -p "$BINDIR"; ln -sf "$HOME/.local/share/divvy-nvim/bin/nvim" "$BINDIR/nvim"
        rm -rf "$_t"; return 0
    fi
    pm_install neovim   # distro package as last resort (may be older)
}

install_micro() {
    case "$PM" in brew) pm_install micro && return 0 ;; esac
    say "Installing micro via its official script…"
    mkdir -p "$BINDIR"
    ( cd "$BINDIR" && { have curl && curl -fsSL https://getmic.ro | sh || { have wget && wget -qO- https://getmic.ro | sh; }; } )
}

install_vim() { pm_install vim; }

install_ghostty() {
    case "$PM" in
        brew)   brew install --cask ghostty && return 0 ;;
        pacman) pm_install ghostty && return 0 ;;
    esac
    warn "Ghostty has no single-command install on this system yet."
    info "See https://ghostty.org/docs/install for your distro — or just keep your current terminal."
    return 0
}

install_font() {
    if [ "$PM" = brew ]; then brew install --cask font-jetbrains-mono-nerd-font || true; return 0; fi
    _fdir="$HOME/.local/share/fonts"; mkdir -p "$_fdir"
    if ls "$_fdir"/JetBrainsMono*Nerd* >/dev/null 2>&1; then ok "Nerd Font already installed"; return 0; fi
    need unzip
    _u=$(gh_asset ryanoasis/nerd-fonts "JetBrainsMono.zip")
    [ -n "$_u" ] || _u="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    _t=$(mktemp -d); fetch "$_u" "$_t/f.zip" && unzip -q "$_t/f.zip" -d "$_fdir" || { rm -rf "$_t"; return 1; }
    have fc-cache && fc-cache -f >/dev/null 2>&1
    rm -rf "$_t"
}

install_agent() {
    case "$1" in
        codex)
            [ "$PM" = brew ] && { brew install --cask codex && return 0; }
            have npm && { npm install -g @openai/codex && return 0; }
            warn "codex: install with 'npm install -g @openai/codex' (needs Node.js)"; return 1 ;;
        gemini)
            [ "$PM" = brew ] && { brew install gemini-cli && return 0; }
            have npm && { npm install -g @google/gemini-cli && return 0; }
            warn "gemini: install with 'npm install -g @google/gemini-cli' (needs Node.js)"; return 1 ;;
        opencode)
            [ "$PM" = brew ] && { brew install opencode && return 0; }
            have npm && { npm install -g opencode-ai && return 0; }
            warn "opencode: see https://opencode.ai/docs for install"; return 1 ;;
        aider)
            [ "$PM" = brew ] && { brew install aider && return 0; }
            have pipx && { pipx install aider-chat && return 0; }
            have pip3 && { pip3 install --user aider-chat && return 0; }
            warn "aider: install with 'pipx install aider-chat' (needs Python)"; return 1 ;;
        goose)
            [ "$PM" = brew ] && { brew install block-goose-cli && return 0; }
            warn "goose: see https://block.github.io/goose/ to install"; return 1 ;;
    esac
}

# Install <cmd> using <install_fn>, with a friendly <label>. Never aborts the script.
ensure() {
    _cmd="$1"; _fn="$2"; _label="$3"
    if have "$_cmd"; then ok "$_label already installed"; return 0; fi
    if [ "$DRY_RUN" = 1 ]; then info "[dry-run] would install $_label"; return 0; fi
    say "Installing $_label…"
    if "$_fn"; then
        if have "$_cmd"; then ok "$_label installed"; else warn "$_label installed but '$_cmd' not on PATH — check $BINDIR"; fi
    else
        warn "$_label: automatic install failed — see the note above"
    fi
    return 0
}

# ─────────────── interactive questions ───────────────
if [ "$INTERACTIVE" = 1 ]; then
    head "divvy — guided installer"
    echo "Base (always installed): zellij + yazi. Pick the rest below."
    echo
    echo "Editors — the central pane editor. nvim is recommended (opens many files as tabs)."
    multiselect "Editors  —  space to toggle · ↑/↓ to move · Enter to confirm" \
        SEL_EDITORS "nvim helix micro vim" "nvim"
    ask_yn "Install Ghostty (a fast terminal with true color, recommended)?" n && WANT_GHOSTTY=1 || WANT_GHOSTTY=0
    ask_yn "Install JetBrainsMono Nerd Font (needed for icons)?" y && WANT_FONT=1 || WANT_FONT=0
    echo
    echo "AI agents — the right-hand pane. 'claude' and 'agy' install separately with your account."
    multiselect "AI agents  —  space to toggle · ↑/↓ to move · Enter to confirm" \
        SEL_AGENTS "codex gemini opencode aider goose" ""
fi
[ "$WANT_GHOSTTY" = ask ] && WANT_GHOSTTY=0
[ "$WANT_FONT" = ask ] && WANT_FONT=1

# ─────────────── summary ───────────────
head "About to install:"
echo "  core:     zellij, yazi"
echo "  editors:  $SEL_EDITORS"
echo "  ghostty:  $([ "$WANT_GHOSTTY" = 1 ] && echo yes || echo no)"
echo "  font:     $([ "$WANT_FONT" = 1 ] && echo yes || echo no)"
echo "  agents:   ${SEL_AGENTS:-(none)}"
echo "  symlinks: $BINDIR"
echo "  manager:  $PM"
[ "$DRY_RUN" = 1 ] && warn "DRY-RUN: nothing will actually be installed."
if [ "$DRY_RUN" = 0 ] && [ "$ASSUME_YES" = 0 ] && [ "$INTERACTIVE" = 1 ]; then
    ask_yn "Continue?" y || { echo "Cancelled."; exit 0; }
fi

if [ "$PM" = none ] && ! have curl && ! have wget; then
    warn "No package manager and no curl/wget found — automatic install won't work."
    info "Install 'curl' (or Homebrew on macOS) and re-run."
fi

# ─────────────── install: core ───────────────
head "Installing core (zellij + yazi)…"
ensure zellij install_zellij "zellij (window manager)"
ensure yazi   install_yazi   "yazi (file manager)"

# ─────────────── install: editors ───────────────
head "Installing editors…"
for ed in $SEL_EDITORS; do
    case "$ed" in
        nvim)  ensure nvim  install_nvim  "Neovim" ;;
        helix) ensure hx    install_helix "Helix" ;;
        micro) ensure micro install_micro "micro" ;;
        vim)   ensure vim   install_vim   "Vim" ;;
        *) warn "unknown editor: $ed (skipped)" ;;
    esac
done

# ─────────────── install: Ghostty ───────────────
if [ "$WANT_GHOSTTY" = 1 ]; then
    head "Installing Ghostty…"
    if [ "$DRY_RUN" = 1 ]; then info "[dry-run] would install Ghostty"; else install_ghostty; fi
fi

# ─────────────── install: Nerd Font ───────────────
if [ "$WANT_FONT" = 1 ]; then
    head "Installing Nerd Font…"
    if [ "$DRY_RUN" = 1 ]; then info "[dry-run] would install JetBrainsMono Nerd Font"; else install_font || warn "Could not install the font automatically — get it at https://nerdfonts.com"; fi
fi

# ─────────────── install: agents ───────────────
if [ -n "$SEL_AGENTS" ]; then
    head "Installing AI agents…"
    for ag in $SEL_AGENTS; do
        case "$ag" in
            codex|gemini|opencode|aider|goose)
                if have "$ag"; then ok "$ag already installed"
                elif [ "$DRY_RUN" = 1 ]; then info "[dry-run] would install $ag"
                else say "Installing $ag…"; install_agent "$ag" || true; fi ;;
            claude) warn "claude: install with 'npm install -g @anthropic-ai/claude-code' (or your preferred method)" ;;
            agy|antigravity) warn "agy (antigravity): use its official installer" ;;
            *) warn "agent '$ag': install it yourself (divvy accepts any command)" ;;
        esac
    done
fi

# ─────────────── symlinks ───────────────
head "Creating symlinks in $BINDIR…"
if [ "$DRY_RUN" = 1 ]; then
    info "[dry-run] divvy divvy-edit divvy-open divvy-theme divvy-clean -> $BINDIR"
else
    mkdir -p "$BINDIR"
    for s in divvy divvy-edit divvy-open divvy-theme divvy-clean; do
        chmod +x "$DIR/$s"; ln -sf "$DIR/$s" "$BINDIR/$s"
    done
    case ":$PATH:" in
        *":$BINDIR:"*) ;;
        *) warn "Add $BINDIR to your PATH:  export PATH=\"$BINDIR:\$PATH\""
           info "(put that line in your ~/.bashrc or ~/.zshrc so it sticks)" ;;
    esac
fi

# ─────────────── zellij config (theme + frames) ───────────────
if [ "$DRY_RUN" = 0 ]; then
    ZCFG="$HOME/.config/zellij/config.kdl"; mkdir -p "$(dirname "$ZCFG")"
    if [ ! -f "$ZCFG" ] || ! grep -q '^theme ' "$ZCFG" 2>/dev/null; then
        say "Setting up the zellij theme…"
        printf 'theme "dracula"\nui {\n    pane_frames {\n        rounded_corners true\n    }\n}\n' >> "$ZCFG"
    fi
    # Jump straight to each pane of the divvy layout: Ctrl/Alt + 1..4 (files|editor|agent|terminal)
    if ! grep -q 'divvy-nav' "$ZCFG" 2>/dev/null; then
        say "Setting up zellij pane navigation (Ctrl/Alt 1-4)…"
        cat >> "$ZCFG" <<'EOF'
keybinds {
    // divvy-nav: jump directly to each pane of the divvy layout
    shared_except "locked" {
        bind "Ctrl 1" "Alt 1" { MoveFocus "up"; MoveFocus "left"; MoveFocus "left"; }                    // files
        bind "Ctrl 2" "Alt 2" { MoveFocus "up"; MoveFocus "left"; MoveFocus "left"; MoveFocus "right"; } // editor
        bind "Ctrl 3" "Alt 3" { MoveFocus "up"; MoveFocus "right"; MoveFocus "right"; }                  // agent
        bind "Ctrl 4" "Alt 4" { MoveFocus "down"; MoveFocus "down"; }                                    // terminal
    }
}
EOF
    fi
fi

# ─────────────── Ghostty config (only if installed) ───────────────
if [ "$DRY_RUN" = 0 ] && { have ghostty || [ -d /Applications/Ghostty.app ]; }; then
    GCFG="$HOME/.config/ghostty/config"
    if [ ! -f "$GCFG" ]; then
        say "Setting up Ghostty…"; mkdir -p "$(dirname "$GCFG")"
        cat > "$GCFG" <<EOF
theme = Dracula
font-family = "JetBrainsMono Nerd Font"
font-size = 14
background-opacity = 0.96
window-padding-x = 8
window-padding-y = 6
macos-option-as-alt = true
keybind = cmd+shift+r=reload_config
EOF
    fi
fi

# ─────────────── Neovim plugins (only if nvim was installed) ───────────────
case " $SEL_EDITORS " in
    *" nvim "*)
        if [ "$DRY_RUN" = 0 ] && have nvim; then
            # nvim-treesitter (main branch) needs the 'tree-sitter' CLI to build parsers.
            if ! have tree-sitter; then
                say "Installing the tree-sitter CLI (for nvim syntax highlighting)…"
                if   have npm;   then npm install -g tree-sitter-cli || warn "install tree-sitter-cli by hand"
                elif have cargo; then cargo install tree-sitter-cli || warn "install tree-sitter-cli by hand"
                else warn "Install the 'tree-sitter' CLI (npm i -g tree-sitter-cli) for highlighting."; fi
            fi
            say "Pre-installing nvim plugins (this can take a moment)…"
            XDG_CONFIG_HOME="$DIR/.config" XDG_DATA_HOME="$DIR/.local/share" XDG_STATE_HOME="$DIR/.local/state" \
                nvim --headless "+Lazy! sync" +qa 2>/dev/null || warn "Open nvim once to finish plugin setup: nvim"
            say "Building treesitter parsers…"
            XDG_CONFIG_HOME="$DIR/.config" XDG_DATA_HOME="$DIR/.local/share" XDG_STATE_HOME="$DIR/.local/state" \
                nvim --headless -c "lua require('nvim-treesitter').install({'lua','vim','vimdoc','bash','json','yaml','toml','javascript','typescript','tsx','html','css','python','markdown','markdown_inline'}):wait(300000)" -c 'qa' 2>/dev/null || warn "Parsers will build the first time you open nvim."
        fi ;;
esac

# ─────────────── apply current theme ───────────────
if [ "$DRY_RUN" = 0 ] && [ -f "$DIR/.theme" ]; then
    "$BINDIR/divvy-theme" "$(cat "$DIR/.theme")" >/dev/null 2>&1 || true
fi

head "Done!"
echo "Open your terminal (Ghostty recommended) and run:  divvy"
echo "Help:  divvy --help   ·   themes:  divvy-theme <name>"
