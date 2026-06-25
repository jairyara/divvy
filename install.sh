#!/bin/sh
# install.sh — guided installer for divvy (macOS / Linux).
# Interactive by default: you choose what to install. It also accepts flags.
#
# Usage:
#   ./install.sh                      # guided (asks questions)
#   ./install.sh --all                # everything (editors, all terminals, brew agents)
#   ./install.sh --minimal            # core + nvim, nothing else
#   ./install.sh --editors "nvim helix" --terminals "ghostty kitty" --agents "codex" --yes
#   BINDIR=/usr/local/bin ./install.sh
#
# Terminals are optional: divvy runs inside zellij, so it works in ANY true-color
# terminal. Picking one just makes the installer set it up and theme it for you.
# A Nerd Font is installed by you (manual) — see the note printed at the end.
#
# It tries your system package manager first (brew, apt, dnf, pacman, zypper, apk).
# If a tool isn't packaged for your system, it downloads the official prebuilt
# binary into ~/.local/bin so you don't have to install anything by hand.
#
# No 'set -e' on purpose: the installer reports each error and keeps going,
# so one tool failing never stops the rest from installing.

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
hdr()  { printf '\n\033[1;36m%s\033[0m\n' "$1"; }        # section title (NOT 'head': that shadows the head command used in pipes)

have() { command -v "$1" >/dev/null 2>&1; }              # is command available?

# Pretty ANSI cover (purple), shown once at the top of the installer.
banner() {
    printf '\033[1;35m'
    cat <<'ART'
 ██████╗ ██╗██╗   ██╗██╗   ██╗██╗   ██╗
 ██╔══██╗██║██║   ██║██║   ██║╚██╗ ██╔╝
 ██║  ██║██║██║   ██║██║   ██║ ╚████╔╝
 ██║  ██║██║╚██╗ ██╔╝╚██╗ ██╔╝  ╚██╔╝
 ██████╔╝██║ ╚████╔╝  ╚████╔╝    ██║
 ╚═════╝ ╚═╝  ╚═══╝    ╚═══╝     ╚═╝
ART
    printf '\033[0m\033[2m a split terminal you can divvy up\033[0m\n'
}

# ─────────────── selection (defaults) ───────────────
SEL_EDITORS="nvim"           # nvim helix micro vim (nvim = default)
SEL_TERMS=""                 # ghostty wezterm kitty alacritty (optional; none by default)
SEL_AGENTS=""                # codex opencode aider goose agy
ASSUME_YES=0
DRY_RUN=0
INTERACTIVE=1

# ─────────────── flags ───────────────
while [ $# -gt 0 ]; do
    case "$1" in
        --all)      SEL_EDITORS="nvim helix micro vim"; SEL_TERMS="ghostty wezterm kitty alacritty";
                    SEL_AGENTS="claude codex opencode aider goose agy"; INTERACTIVE=0; shift ;;
        --minimal)  SEL_EDITORS="nvim"; SEL_TERMS=""; SEL_AGENTS=""; INTERACTIVE=0; shift ;;
        --editors)   SEL_EDITORS="$2"; INTERACTIVE=0; shift 2 ;;
        --terminals) SEL_TERMS="$2"; INTERACTIVE=0; shift 2 ;;
        --agents)    SEL_AGENTS="$2"; INTERACTIVE=0; shift 2 ;;
        --no-ghostty) SEL_TERMS="$(printf '%s' "$SEL_TERMS" | sed 's/ghostty//')"; INTERACTIVE=0; shift ;;
        --ghostty)    case " $SEL_TERMS " in *" ghostty "*) ;; *) SEL_TERMS="ghostty $SEL_TERMS" ;; esac; INTERACTIVE=0; shift ;;
        --no-font|--font) warn "Nerd Font is now a manual step ($1 ignored)"; shift ;;
        --yes|-y)     ASSUME_YES=1; INTERACTIVE=0; shift ;;
        --dry-run)    DRY_RUN=1; shift ;;
        -h|--help)
            sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) warn "Unknown option: $1"; exit 1 ;;
    esac
done
[ -t 0 ] || INTERACTIVE=0    # no interactive terminal → don't ask
banner

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

# Make sure a helper tool (tar, unzip, xz…) is present; install it via the PM if not.
need() {
    have "$1" && return 0
    say "Installing '$1' (needed to unpack downloads)…"
    pm_install "$1" || warn "couldn't install '$1' automatically — install it and re-run"
    have "$1"
}

# Download a URL to a file using curl or wget, whichever exists.
# curl: -g disables URL globbing (avoids "bad range in URL position" errors),
#       -L follows the redirect from /releases/latest/download/, --retry adds resilience.
fetch() {
    if   have curl; then curl -fgsSL --retry 2 "$1" -o "$2"
    elif have wget; then wget -q -O "$2" "$1"
    else warn "need 'curl' or 'wget' to download files"; return 1; fi
}

# Print the download URL of the latest GitHub release asset matching a substring.
# Only used for tools whose asset name contains a version (e.g. helix); everything
# else uses the stable /releases/latest/download/<asset> URL and skips the API.
#   gh_asset <owner/repo> <substring>
gh_asset() {
    _api="https://api.github.com/repos/$1/releases/latest"
    if   have curl; then _json=$(curl -fgsSL "$_api" 2>/dev/null)
    elif have wget; then _json=$(wget -qO- "$_api" 2>/dev/null)
    else return 1; fi
    printf '%s\n' "$_json" \
        | grep -o '"browser_download_url": *"[^"]*"' \
        | sed 's/.*"\(http[^"]*\)".*/\1/' \
        | grep "$2" | head -1
}

# Resolve the latest release tag WITHOUT the GitHub API, by following the redirect
# from /releases/latest and reading the tag off the final URL. Curl-only fallback.
#   gh_latest_tag <owner/repo>   ->   prints e.g. 25.07.1
gh_latest_tag() {
    have curl || return 1
    _final=$(curl -fgsSLI -o /dev/null -w '%{url_effective}' "$GH/$1/releases/latest" 2>/dev/null)
    case "$_final" in *"/tag/"*) printf '%s\n' "${_final##*/tag/}" ;; *) return 1 ;; esac
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

# ─────────────── download helpers ───────────────
GH="https://github.com"   # base; we use /<repo>/releases/latest/download/<asset>

# Extract archive ($1) of kind ($2: tgz|txz|zip) into dir ($3).
extract() {
    case "$2" in
        tgz) need tar          && tar -xzf "$1" -C "$3" ;;
        txz) need tar && need xz && tar -xJf "$1" -C "$3" ;;
        zip) need unzip        && unzip -qo "$1" -d "$3" ;;
        *)   return 1 ;;
    esac
}

# Download a release archive from a *known* URL and install one or more binaries
# into BINDIR. The first <bin> is required; extras are best-effort.
#   dl_install <url> <tgz|txz|zip> <bin> [extra-bins...]
dl_install() {
    _url=$1; _kind=$2; shift 2; _primary=$1
    _t=$(mktemp -d) || return 1
    if ! fetch "$_url" "$_t/archive"; then warn "download failed: $_url"; rm -rf "$_t"; return 1; fi
    if ! extract "$_t/archive" "$_kind" "$_t"; then warn "could not extract $_url"; rm -rf "$_t"; return 1; fi
    mkdir -p "$BINDIR"; _missing=0
    for _b in "$@"; do
        _f=$(find "$_t" -type f -name "$_b" 2>/dev/null | head -1)
        if [ -n "$_f" ]; then install -m 0755 "$_f" "$BINDIR/$_b"
        elif [ "$_b" = "$_primary" ]; then _missing=1; fi
    done
    rm -rf "$_t"
    [ "$_missing" = 0 ] || { warn "binary '$_primary' not found inside the archive"; return 1; }
    return 0
}

# ─────────────── per-tool installers ───────────────
# Each function tries the package manager first, then a prebuilt binary download
# (the reliable cross-distro path). Returns 0 on success.

install_zellij() {
    case "$PM" in brew|pacman) pm_install zellij && return 0 ;; esac
    if [ "$OS" = Darwin ]
    then dl_install "$GH/zellij-org/zellij/releases/latest/download/zellij-$ARCH-apple-darwin.tar.gz" tgz zellij
    else dl_install "$GH/zellij-org/zellij/releases/latest/download/zellij-$ARCH-unknown-linux-musl.tar.gz" tgz zellij
    fi
}

install_yazi() {
    case "$PM" in brew|pacman) pm_install yazi && return 0 ;; esac
    if [ "$OS" = Darwin ]
    then dl_install "$GH/sxyazi/yazi/releases/latest/download/yazi-$ARCH-apple-darwin.zip" zip yazi ya
    else dl_install "$GH/sxyazi/yazi/releases/latest/download/yazi-$ARCH-unknown-linux-musl.zip" zip yazi ya
    fi
}

# Best-effort: yazi's recommended helpers. 'file' is required (mime detection); fd and
# ripgrep power its search. Package names vary, so we just try and never fail the install.
install_yazi_extras() {
    [ "$DRY_RUN" = 1 ] && return 0
    have file || pm_install file >/dev/null 2>&1 || warn "yazi: install 'file' for file-type detection"
    have rg   || pm_install ripgrep >/dev/null 2>&1 || true
    if ! have fd && ! have fdfind; then
        case "$PM" in
            apt|dnf) pm_install fd-find >/dev/null 2>&1 || true ;;
            *)       pm_install fd      >/dev/null 2>&1 || true ;;
        esac
    fi
    return 0
}

install_helix() {
    # Native package first — it also drops the 'runtime' dir for us.
    case "$PM" in
        brew|pacman|zypper|apk) pm_install helix && have hx && return 0 ;;
        dnf) { pm_install helix || { $SUDO dnf -y copr enable varlad/helix && pm_install helix; }; } && have hx && return 0 ;;
        apt) { have add-apt-repository && $SUDO add-apt-repository -y ppa:maveonair/helix-editor && pm_install helix; } && have hx && return 0 ;;
    esac
    # Prebuilt binary. The asset name embeds the version, so resolve it via the API and,
    # if that's rate-limited/unavailable, via the API-less /releases/latest redirect.
    _u=$(gh_asset helix-editor/helix "$ARCH-linux.tar.xz")
    if [ -z "$_u" ]; then
        _tag=$(gh_latest_tag helix-editor/helix)
        [ -n "$_tag" ] && _u="$GH/helix-editor/helix/releases/download/$_tag/helix-$_tag-$ARCH-linux.tar.xz"
    fi
    if [ -z "$_u" ]; then warn "helix: couldn't resolve a download URL (arch=$ARCH)"; return 1; fi
    _t=$(mktemp -d) || return 1
    fetch "$_u" "$_t/h.txz" || { warn "download failed: $_u"; rm -rf "$_t"; return 1; }
    extract "$_t/h.txz" txz "$_t" || { warn "could not extract helix"; rm -rf "$_t"; return 1; }
    _d=$(find "$_t" -maxdepth 1 -type d -name 'helix-*' | head -1)
    [ -n "$_d" ] || { warn "helix archive layout unexpected"; rm -rf "$_t"; return 1; }
    mkdir -p "$BINDIR"; install -m 0755 "$_d/hx" "$BINDIR/hx"
    mkdir -p "$HOME/.config/helix"; rm -rf "$HOME/.config/helix/runtime"
    cp -r "$_d/runtime" "$HOME/.config/helix/runtime"
    rm -rf "$_t"; return 0
}

install_nvim() {
    case "$PM" in brew) pm_install neovim && return 0 ;; esac
    # Distro neovim is often too old for our config, so prefer the official binary.
    if [ "$OS" = Darwin ]
    then case "$ARCH" in aarch64) _f=nvim-macos-arm64 ;; *) _f=nvim-macos-x86_64 ;; esac
    else case "$ARCH" in aarch64) _f=nvim-linux-arm64 ;; *) _f=nvim-linux-x86_64 ;; esac
    fi
    _t=$(mktemp -d) || return 1
    if fetch "$GH/neovim/neovim/releases/latest/download/$_f.tar.gz" "$_t/n.tgz" && extract "$_t/n.tgz" tgz "$_t"; then
        _d=$(find "$_t" -maxdepth 1 -type d -name 'nvim-*' | head -1)
        if [ -n "$_d" ]; then
            rm -rf "$HOME/.local/share/divvy-nvim"; mkdir -p "$HOME/.local/share"
            cp -r "$_d" "$HOME/.local/share/divvy-nvim"
            mkdir -p "$BINDIR"; ln -sf "$HOME/.local/share/divvy-nvim/bin/nvim" "$BINDIR/nvim"
            rm -rf "$_t"; return 0
        fi
    fi
    rm -rf "$_t"
    warn "Falling back to the distro neovim (may be older than our config needs)."
    pm_install neovim
}

install_micro() {
    case "$PM" in brew) pm_install micro && return 0 ;; esac
    mkdir -p "$BINDIR"
    say "Installing micro via its official script…"
    if   have curl; then ( cd "$BINDIR" && curl -fgsSL https://getmic.ro | sh ) && return 0
    elif have wget; then ( cd "$BINDIR" && wget -qO- https://getmic.ro | sh ) && return 0
    else warn "micro: need curl or wget to install"; return 1; fi
}

install_vim() { pm_install vim; }

install_ghostty() {
    # Methods per https://ghostty.org/docs/install/binary
    # Official / distro-maintained packages first:
    case "$PM" in
        brew)   brew install --cask ghostty && return 0 ;;   # macOS cask
        pacman) pm_install ghostty && return 0 ;;             # Arch [extra]
        apk)    pm_install ghostty && return 0 ;;             # Alpine testing repo
        # openSUSE (zypper) dropped Ghostty over Zig versioning → fall through.
    esac
    have xbps-install && { say "Installing Ghostty (Void)…"; $SUDO xbps-install -Sy ghostty && return 0; }
    have emerge       && { say "Installing Ghostty (Gentoo)…"; $SUDO emerge -av ghostty && return 0; }
    have eopkg        && { say "Installing Ghostty (Solus)…"; $SUDO eopkg install -y ghostty && return 0; }
    have nix          && { say "Installing Ghostty (Nix)…"; nix profile install nixpkgs#ghostty && return 0; }
    # Snap is built with Ghostty's own scripts and works across most distros.
    have snap && { say "Installing Ghostty via snap…"; $SUDO snap install ghostty --classic && return 0; }
    # Fedora: community COPR repo.
    if [ "$PM" = dnf ]; then
        say "Enabling the Ghostty COPR repo (community)…"
        $SUDO dnf -y copr enable scottames/ghostty && pm_install ghostty && return 0
    fi
    # Ubuntu: community installer script recommended by the Ghostty docs.
    if [ "$PM" = apt ] && have bash && have curl; then
        say "Installing Ghostty via the community Ubuntu installer…"
        bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)" && return 0
    fi
    warn "Couldn't install Ghostty automatically on this system."
    info "See https://ghostty.org/docs/install/binary (there's also a universal AppImage)."
    info "divvy works fine in your current terminal — Ghostty is only for nicer true-color themes."
    return 0
}

# WezTerm / Kitty / Alacritty are well packaged everywhere, so a single PM path
# (plus brew cask on macOS) covers almost every system.
install_wezterm() {
    case "$PM" in
        brew)   brew install --cask wezterm && return 0 ;;
        pacman) pm_install wezterm && return 0 ;;
        apk)    pm_install wezterm && return 0 ;;
    esac
    have flatpak && { say "Installing WezTerm via Flatpak…"; flatpak install -y flathub org.wezfurlong.wezterm && return 0; }
    warn "Couldn't install WezTerm automatically — see https://wezterm.org/installation"; return 1
}

install_kitty() {
    case "$PM" in
        brew)   brew install --cask kitty && return 0 ;;
        pacman) pm_install kitty && return 0 ;;
        dnf)    pm_install kitty && return 0 ;;
        apt)    pm_install kitty && return 0 ;;
        zypper) pm_install kitty && return 0 ;;
        apk)    pm_install kitty && return 0 ;;
    esac
    # Official cross-distro installer → ~/.local/kitty.app, symlink into BINDIR.
    if have curl || have wget; then
        say "Installing kitty via its official installer…"
        if have curl; then sh -c "$(curl -fgsSL https://sw.kovidgoyal.net/kitty/installer.sh)" || return 1
        else sh -c "$(wget -qO- https://sw.kovidgoyal.net/kitty/installer.sh)" || return 1; fi
        mkdir -p "$BINDIR"
        ln -sf "$HOME/.local/kitty.app/bin/kitty" "$BINDIR/kitty" 2>/dev/null
        ln -sf "$HOME/.local/kitty.app/bin/kitten" "$BINDIR/kitten" 2>/dev/null
        return 0
    fi
    warn "Couldn't install kitty automatically — see https://sw.kovidgoyal.net/kitty/binary/"; return 1
}

install_alacritty() {
    case "$PM" in
        brew)   brew install --cask alacritty && return 0 ;;
        pacman) pm_install alacritty && return 0 ;;
        dnf)    pm_install alacritty && return 0 ;;
        apt)    pm_install alacritty && return 0 ;;
        zypper) pm_install alacritty && return 0 ;;
        apk)    pm_install alacritty && return 0 ;;
    esac
    warn "Couldn't install Alacritty automatically — see https://alacritty.org (cargo install alacritty)"; return 1
}

install_agent() {
    case "$1" in
        claude)
            have npm  && { npm install -g @anthropic-ai/claude-code && return 0; }
            # The native installer is a bash script — pipe to bash, not sh.
            have bash && have curl && { curl -fgsSL https://claude.ai/install.sh | bash && return 0; }
            have bash && have wget && { wget -qO- https://claude.ai/install.sh | bash && return 0; }
            warn "claude: install with 'npm install -g @anthropic-ai/claude-code' (needs Node.js)"; return 1 ;;
        codex)
            [ "$PM" = brew ] && { brew install --cask codex && return 0; }
            have npm && { npm install -g @openai/codex && return 0; }
            warn "codex: install with 'npm install -g @openai/codex' (needs Node.js)"; return 1 ;;
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
        agy|antigravity)
            # Antigravity's installer is a bash script — pipe to bash, not sh.
            have bash && have curl && { curl -fgsSL https://antigravity.google/cli/install.sh | bash && return 0; }
            have bash && have wget && { wget -qO- https://antigravity.google/cli/install.sh | bash && return 0; }
            warn "agy: install with 'curl -fsSL https://antigravity.google/cli/install.sh | bash'"; return 1 ;;
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
    hdr "divvy — guided installer"
    echo "Base (always installed): zellij + yazi. Pick the rest below."
    echo
    echo "Editors — the central pane editor. nvim is recommended (opens many files as tabs)."
    multiselect "Editors  —  space to toggle · ↑/↓ to move · Enter to confirm" \
        SEL_EDITORS "nvim helix micro vim" "nvim"
    echo
    echo "Terminals — optional. divvy works in ANY true-color terminal; pick one to have it"
    echo "installed and auto-themed (Ghostty is a great default). Skip to use your current one."
    multiselect "Terminals  —  space to toggle · ↑/↓ to move · Enter to confirm" \
        SEL_TERMS "ghostty wezterm kitty alacritty" "ghostty"
    echo
    echo "AI agents — the right-hand pane. claude is divvy's default; 'agy' is Google Antigravity."
    multiselect "AI agents  —  space to toggle · ↑/↓ to move · Enter to confirm" \
        SEL_AGENTS "claude codex opencode aider goose agy" "claude"
fi

# ─────────────── summary ───────────────
hdr "About to install:"
echo "  core:      zellij, yazi"
echo "  editors:   $SEL_EDITORS"
echo "  terminals: ${SEL_TERMS:-(none — use your current terminal)}"
echo "  font:      manual (Nerd Font — see the note at the end)"
echo "  agents:    ${SEL_AGENTS:-(none)}"
echo "  symlinks:  $BINDIR"
echo "  system:    $OS / $ARCH"
echo "  manager:   $PM"
echo "  download:  $(have curl && echo curl || { have wget && echo wget || echo '(none — install curl)'; })"
[ "$DRY_RUN" = 1 ] && warn "DRY-RUN: nothing will actually be installed."
if [ "$DRY_RUN" = 0 ] && [ "$ASSUME_YES" = 0 ] && [ "$INTERACTIVE" = 1 ]; then
    ask_yn "Continue?" y || { echo "Cancelled."; exit 0; }
fi

# ─────────────── bootstrap prerequisites ───────────────
# A fresh distro may lack curl/wget (needed to download tools). Get one via the PM.
if [ "$DRY_RUN" = 0 ] && ! have curl && ! have wget; then
    if [ "$PM" = none ]; then
        warn "No package manager and no curl/wget found — automatic install can't proceed."
        info "Install 'curl' (or Homebrew on macOS) and re-run."
    else
        say "Installing curl (required to download tools)…"
        pm_install curl ca-certificates || pm_install curl || warn "couldn't install curl — install it and re-run"
    fi
fi

# ─────────────── install: core ───────────────
hdr "Installing core (zellij + yazi)…"
ensure zellij install_zellij "zellij (window manager)"
ensure yazi   install_yazi   "yazi (file manager)"
install_yazi_extras

# ─────────────── install: editors ───────────────
hdr "Installing editors…"
for ed in $SEL_EDITORS; do
    case "$ed" in
        nvim)  ensure nvim  install_nvim  "Neovim" ;;
        helix) ensure hx    install_helix "Helix" ;;
        micro) ensure micro install_micro "micro" ;;
        vim)   ensure vim   install_vim   "Vim" ;;
        *) warn "unknown editor: $ed (skipped)" ;;
    esac
done

# ─────────────── install: terminals (optional) ───────────────
if [ -n "$SEL_TERMS" ]; then
    hdr "Installing terminals…"
    for term in $SEL_TERMS; do
        case "$term" in
            ghostty)   ensure ghostty   install_ghostty   "Ghostty" ;;
            wezterm)   ensure wezterm    install_wezterm   "WezTerm" ;;
            kitty)     ensure kitty      install_kitty     "kitty" ;;
            alacritty) ensure alacritty  install_alacritty "Alacritty" ;;
            *) warn "unknown terminal: $term (skipped)" ;;
        esac
    done
fi

# ─────────────── install: agents ───────────────
if [ -n "$SEL_AGENTS" ]; then
    hdr "Installing AI agents…"
    for ag in $SEL_AGENTS; do
        case "$ag" in
            claude|codex|opencode|aider|goose|agy|antigravity)
                if have "$ag"; then ok "$ag already installed"
                elif [ "$DRY_RUN" = 1 ]; then info "[dry-run] would install $ag"
                else say "Installing $ag…"; install_agent "$ag" || true; fi ;;
            *) warn "agent '$ag': install it yourself (divvy accepts any command)" ;;
        esac
    done
fi

# ─────────────── symlinks ───────────────
hdr "Creating symlinks in $BINDIR…"
if [ "$DRY_RUN" = 1 ]; then
    info "[dry-run] divvy divvy-edit divvy-open divvy-theme divvy-clean -> $BINDIR"
else
    mkdir -p "$BINDIR"
    for s in divvy divvy-edit divvy-open divvy-theme divvy-clean; do
        chmod +x "$DIR/$s"; ln -sf "$DIR/$s" "$BINDIR/$s"
    done
    # Make sure BINDIR is on PATH for FUTURE shells — always ensure the line is in the
    # shell rc (idempotent via a marker), even if it happens to be on PATH right now.
    _rc="$HOME/.profile"
    case "${SHELL##*/}" in
        zsh)  _rc="$HOME/.zshrc" ;;
        bash) _rc="$HOME/.bashrc" ;;
    esac
    if grep -qs 'divvy: add ~/.local/bin to PATH' "$_rc" 2>/dev/null; then
        ok "PATH already configured in $_rc"
    elif printf '\n# divvy: add ~/.local/bin to PATH\nexport PATH="%s:$PATH"\n' "$BINDIR" >> "$_rc" 2>/dev/null; then
        ok "Added $BINDIR to your PATH in $_rc"
    else
        warn "Couldn't update $_rc automatically. Add this line to your shell config by hand:"
        info "    export PATH=\"$BINDIR:\$PATH\""
    fi
    # If it's not active in THIS session yet, tell the user how to turn it on now.
    case ":$PATH:" in
        *":$BINDIR:"*) ;;
        *) info "Not active in this shell yet — run:  source $_rc   (or open a new terminal)" ;;
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

# ─────────────── terminal configs (only for installed terminals) ───────────────
# We only WRITE a config when none exists (never clobber yours). Themes are applied
# later by divvy-theme, which rewrites just the theme line in whatever config exists.
if [ "$DRY_RUN" = 0 ]; then
    # Ghostty — built-in themes
    if have ghostty || [ -d /Applications/Ghostty.app ]; then
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
    # WezTerm — built-in color schemes
    if have wezterm || [ -d /Applications/WezTerm.app ]; then
        WCFG="$HOME/.config/wezterm/wezterm.lua"
        if [ ! -f "$WCFG" ]; then
            say "Setting up WezTerm…"; mkdir -p "$(dirname "$WCFG")"
            cat > "$WCFG" <<EOF
local wezterm = require("wezterm")
return {
  color_scheme = "Dracula",
  font = wezterm.font("JetBrainsMono Nerd Font"),
  font_size = 14.0,
  window_padding = { left = 8, right = 8, top = 6, bottom = 6 },
  enable_tab_bar = false,
}
EOF
        fi
    fi
    # kitty — theme bundled in repo, included via a stable file divvy-theme rewrites
    if have kitty || [ -d /Applications/kitty.app ]; then
        KCFG="$HOME/.config/kitty/kitty.conf"
        if [ ! -f "$KCFG" ]; then
            say "Setting up kitty…"; mkdir -p "$(dirname "$KCFG")"
            cat > "$KCFG" <<EOF
font_family JetBrainsMono Nerd Font
font_size 14.0
window_padding_width 6
include divvy-theme.conf
EOF
            cp "$DIR/kitty/themes/dracula.conf" "$HOME/.config/kitty/divvy-theme.conf" 2>/dev/null
        fi
    fi
    # Alacritty — theme bundled in repo, imported via a stable file divvy-theme rewrites
    if have alacritty || [ -d /Applications/Alacritty.app ]; then
        ACFG="$HOME/.config/alacritty/alacritty.toml"
        if [ ! -f "$ACFG" ]; then
            say "Setting up Alacritty…"; mkdir -p "$(dirname "$ACFG")"
            cat > "$ACFG" <<EOF
[general]
import = ["$HOME/.config/alacritty/divvy-theme.toml"]

[font]
size = 14.0

[font.normal]
family = "JetBrainsMono Nerd Font"

[window.padding]
x = 8
y = 6
EOF
            cp "$DIR/alacritty/themes/dracula.toml" "$HOME/.config/alacritty/divvy-theme.toml" 2>/dev/null
        fi
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

hdr "One manual step: install a Nerd Font"
echo "Icons in yazi and the status line need a Nerd Font. Install one yourself:"
case "$OS" in
    Darwin) info "macOS:  brew install --cask font-jetbrains-mono-nerd-font" ;;
    *)      info "Linux:  download JetBrainsMono from https://www.nerdfonts.com/font-downloads," ;;
esac
[ "$OS" = Darwin ] || info "        unzip into ~/.local/share/fonts, then run: fc-cache -f"
info "Then select \"JetBrainsMono Nerd Font\" in your terminal's settings."
info "(divvy's terminal configs already point to it — no change needed once it's installed.)"

hdr "Done!"
echo "Open your terminal and run:  divvy"
echo "Help:  divvy --help   ·   themes:  divvy-theme <name>"
