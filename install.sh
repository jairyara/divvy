#!/bin/sh
# install.sh — instalador guiado de divvy (macOS / Linux).
# Por defecto es INTERACTIVO: eliges qué instalar. También acepta flags.
#
# Uso:
#   ./install.sh                      # guiado (preguntas)
#   ./install.sh --all                # todo (editores, Ghostty, fuente, agentes brew)
#   ./install.sh --minimal            # core + helix, nada más
#   ./install.sh --editors "helix nvim" --agents "codex gemini" --no-ghostty --yes
#   BINDIR=/usr/local/bin ./install.sh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
BINDIR="${BINDIR:-$HOME/.local/bin}"
OS="$(uname -s)"

say()  { printf '\033[1;35m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$1"; }
head() { printf '\n\033[1;36m%s\033[0m\n' "$1"; }

# ─────────────── selección (defaults) ───────────────
SEL_EDITORS="helix"          # helix nvim micro vim
WANT_GHOSTTY=ask             # ask|1|0
WANT_FONT=ask
SEL_AGENTS=""                # codex gemini opencode aider goose
ASSUME_YES=0
DRY_RUN=0
INTERACTIVE=1

# ─────────────── flags ───────────────
while [ $# -gt 0 ]; do
    case "$1" in
        --all)      SEL_EDITORS="helix nvim micro vim"; WANT_GHOSTTY=1; WANT_FONT=1;
                    SEL_AGENTS="codex gemini opencode aider goose"; INTERACTIVE=0; shift ;;
        --minimal)  SEL_EDITORS="helix"; WANT_GHOSTTY=0; WANT_FONT=0; SEL_AGENTS=""; INTERACTIVE=0; shift ;;
        --editors)  SEL_EDITORS="$2"; INTERACTIVE=0; shift 2 ;;
        --agents)   SEL_AGENTS="$2"; INTERACTIVE=0; shift 2 ;;
        --no-ghostty) WANT_GHOSTTY=0; INTERACTIVE=0; shift ;;
        --ghostty)    WANT_GHOSTTY=1; INTERACTIVE=0; shift ;;
        --no-font)    WANT_FONT=0; INTERACTIVE=0; shift ;;
        --font)       WANT_FONT=1; INTERACTIVE=0; shift ;;
        --yes|-y)     ASSUME_YES=1; INTERACTIVE=0; shift ;;
        --dry-run)    DRY_RUN=1; shift ;;
        -h|--help)
            sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) warn "Opción desconocida: $1"; exit 1 ;;
    esac
done
[ -t 0 ] || INTERACTIVE=0    # sin terminal interactiva → no preguntar

# ─────────────── gestor de paquetes ───────────────
if command -v brew >/dev/null 2>&1; then PM=brew
elif command -v pacman >/dev/null 2>&1; then PM=pacman
else PM=none; fi

ask_yn() { # ask_yn "pregunta" default(s/n) -> 0=sí 1=no
    _def="$2"
    if [ "$INTERACTIVE" = 0 ]; then [ "$_def" = s ] && return 0 || return 1; fi
    _hint="[s/N]"; [ "$_def" = s ] && _hint="[S/n]"
    printf "%s %s: " "$1" "$_hint"; read _a 2>/dev/null || _a=""
    [ -z "$_a" ] && _a="$_def"
    case "$_a" in s|S|y|Y|si|SI|yes) return 0 ;; *) return 1 ;; esac
}

# ─────────────── preguntas interactivas ───────────────
if [ "$INTERACTIVE" = 1 ]; then
    head "divvy — instalador guiado"
    echo "Base (siempre): zellij + yazi. Elige el resto."
    printf "Editores a instalar [helix nvim micro vim] (Enter = solo helix): "
    read _e 2>/dev/null || _e=""; [ -n "$_e" ] && SEL_EDITORS="$_e"
    ask_yn "¿Instalar Ghostty (terminal con true color, recomendada)?" n && WANT_GHOSTTY=1 || WANT_GHOSTTY=0
    ask_yn "¿Instalar JetBrainsMono Nerd Font (iconos)?" s && WANT_FONT=1 || WANT_FONT=0
    echo "Agentes IA instalables vía brew: codex gemini opencode aider goose"
    echo "  (claude y agy se instalan aparte con tu cuenta)"
    printf "Agentes a instalar (Enter = ninguno): "
    read _ag 2>/dev/null || _ag=""; SEL_AGENTS="$_ag"
fi
[ "$WANT_GHOSTTY" = ask ] && WANT_GHOSTTY=0
[ "$WANT_FONT" = ask ] && WANT_FONT=1

# ─────────────── resumen ───────────────
head "Se instalará:"
echo "  core:     zellij, yazi"
echo "  editores: $SEL_EDITORS"
echo "  ghostty:  $([ "$WANT_GHOSTTY" = 1 ] && echo sí || echo no)"
echo "  fuente:   $([ "$WANT_FONT" = 1 ] && echo sí || echo no)"
echo "  agentes:  ${SEL_AGENTS:-(ninguno)}"
echo "  symlinks: $BINDIR"
echo "  gestor:   $PM"
[ "$DRY_RUN" = 1 ] && { warn "DRY-RUN: no se instala nada."; }
if [ "$DRY_RUN" = 0 ] && [ "$ASSUME_YES" = 0 ] && [ "$INTERACTIVE" = 1 ]; then
    ask_yn "¿Continuar?" s || { echo "Cancelado."; exit 0; }
fi

# ─────────────── instalar paquete ───────────────
# ensure <cmd> <brew> <pacman> [cask]
ensure() {
    _cmd="$1"; _brew="$2"; _pac="$3"; _cask="$4"
    if command -v "$_cmd" >/dev/null 2>&1; then say "$_cmd ya instalado"; return; fi
    if [ "$DRY_RUN" = 1 ]; then echo "  [dry-run] instalaría $_cmd ($PM)"; return; fi
    case "$PM" in
        brew)   if [ "$_cask" = cask ]; then brew install --cask "$_brew" || warn "falló $_brew";
                else brew install "$_brew" || warn "falló $_brew"; fi ;;
        pacman) [ -n "$_pac" ] && (sudo pacman -S --needed --noconfirm "$_pac" || warn "falló $_pac") \
                              || warn "instala '$_cmd' manualmente (no en pacman)" ;;
        none)   warn "sin brew/pacman: instala '$_cmd' manualmente" ;;
    esac
}

head "Instalando core…"
ensure zellij zellij zellij
ensure yazi   yazi   yazi

head "Instalando editores…"
for ed in $SEL_EDITORS; do
    case "$ed" in
        helix) ensure hx    helix   helix ;;
        nvim)  ensure nvim  neovim  neovim ;;
        micro) ensure micro micro   micro ;;
        vim)   ensure vim   vim     vim ;;
        *) warn "editor desconocido: $ed (ignorado)" ;;
    esac
done

if [ "$WANT_GHOSTTY" = 1 ]; then
    head "Instalando Ghostty…"
    if [ "$PM" = brew ]; then ensure ghostty ghostty "" cask
    else warn "Ghostty: instálalo desde https://ghostty.org"; fi
fi

if [ "$WANT_FONT" = 1 ]; then
    head "Instalando Nerd Font…"
    if [ "$PM" = brew ]; then
        [ "$DRY_RUN" = 1 ] && echo "  [dry-run] font-jetbrains-mono-nerd-font" || brew install --cask font-jetbrains-mono-nerd-font || true
    elif [ "$PM" = pacman ]; then ensure : ttf-jetbrains-mono-nerd ttf-jetbrains-mono-nerd
    else warn "Nerd Font: descarga 'JetBrainsMono Nerd Font' de https://nerdfonts.com"; fi
fi

if [ -n "$SEL_AGENTS" ]; then
    head "Instalando agentes…"
    for ag in $SEL_AGENTS; do
        case "$ag" in
            codex)    ensure codex   codex          codex ;;
            gemini)   ensure gemini  gemini-cli     "" ;;
            opencode) ensure opencode opencode      opencode ;;
            aider)    ensure aider   aider          aider ;;
            goose)    ensure goose   block-goose-cli "" ;;
            claude)   warn "claude: instálalo con  npm i -g @anthropic-ai/claude-code  (o tu método)" ;;
            agy|antigravity) warn "agy (antigravity): instálalo con su instalador oficial" ;;
            *) warn "agente '$ag': instálalo tú (divvy acepta cualquier comando)" ;;
        esac
    done
fi

# ─────────────── symlinks ───────────────
head "Creando symlinks en $BINDIR…"
if [ "$DRY_RUN" = 1 ]; then
    echo "  [dry-run] divvy divvy-edit divvy-open divvy-theme divvy-clean -> $BINDIR"
else
    mkdir -p "$BINDIR"
    for s in divvy divvy-edit divvy-open divvy-theme divvy-clean; do
        chmod +x "$DIR/$s"; ln -sf "$DIR/$s" "$BINDIR/$s"
    done
    case ":$PATH:" in
        *":$BINDIR:"*) ;;
        *) warn "Agrega $BINDIR a tu PATH:  export PATH=\"$BINDIR:\$PATH\"" ;;
    esac
fi

# ─────────────── config zellij (tema + marcos) ───────────────
if [ "$DRY_RUN" = 0 ]; then
    ZCFG="$HOME/.config/zellij/config.kdl"; mkdir -p "$(dirname "$ZCFG")"
    if [ ! -f "$ZCFG" ] || ! grep -q '^theme ' "$ZCFG" 2>/dev/null; then
        say "Configurando tema de zellij…"
        printf 'theme "dracula"\nui {\n    pane_frames {\n        rounded_corners true\n    }\n}\n' >> "$ZCFG"
    fi
    # navegación directa a cada pane: Ctrl/Alt + 1..4 (archivos|editor|agente|terminal)
    if ! grep -q 'divvy-nav' "$ZCFG" 2>/dev/null; then
        say "Configurando navegación de panes de zellij (Ctrl/Alt 1-4)…"
        cat >> "$ZCFG" <<'EOF'
keybinds {
    // divvy-nav: saltar directo a cada pane del layout de divvy
    shared_except "locked" {
        bind "Ctrl 1" "Alt 1" { MoveFocus "up"; MoveFocus "left"; MoveFocus "left"; }                    // archivos
        bind "Ctrl 2" "Alt 2" { MoveFocus "up"; MoveFocus "left"; MoveFocus "left"; MoveFocus "right"; } // editor
        bind "Ctrl 3" "Alt 3" { MoveFocus "up"; MoveFocus "right"; MoveFocus "right"; }                  // agente
        bind "Ctrl 4" "Alt 4" { MoveFocus "down"; MoveFocus "down"; }                                    // terminal
    }
}
EOF
    fi
fi

# ─────────────── config ghostty (solo si está) ───────────────
if [ "$DRY_RUN" = 0 ] && { command -v ghostty >/dev/null 2>&1 || [ -d /Applications/Ghostty.app ]; }; then
    GCFG="$HOME/.config/ghostty/config"
    if [ ! -f "$GCFG" ]; then
        say "Configurando Ghostty…"; mkdir -p "$(dirname "$GCFG")"
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

# ─────────────── plugins de nvim (solo si se instaló nvim) ───────────────
case " $SEL_EDITORS " in
    *" nvim "*)
        if [ "$DRY_RUN" = 0 ] && command -v nvim >/dev/null 2>&1; then
            # nvim-treesitter (rama main) necesita el CLI 'tree-sitter' para compilar parsers
            if ! command -v tree-sitter >/dev/null 2>&1; then
                say "Instalando CLI tree-sitter (para resaltado de nvim)…"
                if   command -v npm   >/dev/null 2>&1; then npm install -g tree-sitter-cli || warn "instala tree-sitter-cli a mano"
                elif command -v cargo >/dev/null 2>&1; then cargo install tree-sitter-cli || warn "instala tree-sitter-cli a mano"
                else warn "Instala el CLI 'tree-sitter' (npm i -g tree-sitter-cli) para el resaltado."; fi
            fi
            say "Pre-instalando plugins de nvim (puede tardar)…"
            XDG_CONFIG_HOME="$DIR/.config" XDG_DATA_HOME="$DIR/.local/share" XDG_STATE_HOME="$DIR/.local/state" \
                nvim --headless "+Lazy! sync" +qa 2>/dev/null || warn "Revisa nvim con: nvim"
            say "Compilando parsers de treesitter…"
            XDG_CONFIG_HOME="$DIR/.config" XDG_DATA_HOME="$DIR/.local/share" XDG_STATE_HOME="$DIR/.local/state" \
                nvim --headless -c "lua require('nvim-treesitter').install({'lua','vim','vimdoc','bash','json','yaml','toml','javascript','typescript','tsx','html','css','python','markdown','markdown_inline'}):wait(300000)" -c 'qa' 2>/dev/null || warn "Parsers se compilarán al abrir nvim."
        fi ;;
esac

# ─────────────── tema actual ───────────────
if [ "$DRY_RUN" = 0 ] && [ -f "$DIR/.theme" ]; then
    "$BINDIR/divvy-theme" "$(cat "$DIR/.theme")" >/dev/null 2>&1 || true
fi

head "¡Listo!"
echo "Abre tu terminal (Ghostty recomendado) y corre:  divvy"
echo "Ayuda:  divvy --help   ·   temas:  divvy-theme <nombre>"
