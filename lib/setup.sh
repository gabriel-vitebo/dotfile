# Shared contract for every module: probe first; healthy = SKIP regardless of origin.
cw_log() { printf '[%s] %s\n' "$1" "$2"; }
cw_probe() {
    cw_version=
    if ! command -v "$1" >/dev/null 2>&1; then return 1; fi
    cw_version=$("$1" --version 2>/dev/null) && [ -n "$cw_version" ] && return 0
    return 2
}
cw_confirm() {
    local answer=
    printf 'Continuar com as alterações acima? [s/N] '
    IFS= read -r answer || return 1
    case "$answer" in s|S|sim|y|Y|yes) return 0 ;; *) return 1 ;; esac
}
cw_is_ubuntu() {
    [ -r /etc/os-release ] && ( . /etc/os-release; [ "${ID:-}" = ubuntu ] )
}
cw_platform() {
    cw_arch=$(uname -m) || return 1
    case "$cw_arch" in x86_64|aarch64|arm64) ;; *) cw_log MANUAL "Arquitetura não suportada: $cw_arch"; return 1 ;; esac
    case "$(uname -s)" in
        Darwin) cw_os=macos ;;
        Linux)
            if cw_is_ubuntu; then cw_os=ubuntu
            else cw_log MANUAL 'Somente Ubuntu e macOS são suportados.'; return 1; fi ;;
        *) cw_log MANUAL 'Somente Ubuntu e macOS são suportados.'; return 1 ;;
    esac
    cw_log CHECK "$cw_os / $cw_arch"
}
cw_fetch() { curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --connect-timeout 15 --max-time 90 "$1"; }
cw_lts_major() {
    # Official tab-separated release index: latest release with an LTS codename.
    local index
    index=$(cw_fetch https://nodejs.org/dist/index.tab) || return 1
    printf '%s\n' "$index" | awk -F '\t' 'NR > 1 && $10 != "-" && $10 != "" {split($1,v,"."); sub(/^v/,"",v[1]); print v[1]; exit}'
}
cw_load_nvm() {
    if command -v nvm >/dev/null 2>&1; then nvm --version >/dev/null 2>&1 && return 0; return 2; fi
    local dir
    if [ -n "${NVM_DIR:-}" ] && [ ! -f "$NVM_DIR/nvm.sh" ]; then
        [ ! -e "$NVM_DIR" ] && [ ! -L "$NVM_DIR" ] && return 1
        return 2
    fi
    for dir in "${NVM_DIR:-}" "$HOME/.nvm" "${XDG_CONFIG_HOME:-$HOME/.config}/nvm" /opt/homebrew/opt/nvm /usr/local/opt/nvm; do
        [ -n "$dir" ] && [ -f "$dir/nvm.sh" ] || continue
        export NVM_DIR="$dir"
        # --no-use preserves the active Node and never reads a project's .nvmrc.
        . "$dir/nvm.sh" --no-use || return 2
        nvm --version >/dev/null 2>&1 && return 0
        return 2
    done
    if [ -e "${NVM_DIR:-$HOME/.nvm}" ]; then return 2; fi
    return 1
}
cw_privileged() {
    if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}
cw_package() {
    # Recheck immediately before mutation, including tools installed since planning.
    local state=0
    cw_probe "$1" || state=$?
    [ "$state" -ne 0 ] || { cw_log SKIP "$1 já funcional"; return 0; }
    [ "$state" -eq 1 ] || { cw_log MANUAL "$1 existe mas falhou; reparo requer autorização específica."; return 1; }
    if [ "$cw_os" = macos ]; then
        HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1 brew install "$1" || return 1
    else
        if [ "$1" = gh ]; then cw_gh_repository || return 1; fi
        cw_privileged apt-get update && cw_privileged apt-get install -y "$1" || return 1
    fi
    cw_probe "$1"
}
cw_gh_repository() (
    set -e
    work=$(mktemp -d) || exit 1
    trap 'rm -rf "$work"' EXIT
    cw_fetch https://cli.github.com/packages/githubcli-archive-keyring.gpg > "$work/key" || exit 1
    [ -s "$work/key" ] || exit 1
    cw_privileged install -d -m 755 /etc/apt/keyrings || exit 1
    if [ -e /etc/apt/keyrings/githubcli-archive-keyring.gpg ]; then
        cmp -s "$work/key" /etc/apt/keyrings/githubcli-archive-keyring.gpg || exit 1
    else
        cw_privileged install -m 644 "$work/key" /etc/apt/keyrings/githubcli-archive-keyring.gpg || exit 1
    fi
    printf 'deb [arch=%s signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' "$(dpkg --print-architecture)" > "$work/source"
    # Never overwrite a preexisting repository configuration.
    if [ -e /etc/apt/sources.list.d/github-cli.list ]; then
        cmp -s "$work/source" /etc/apt/sources.list.d/github-cli.list || exit 1
    else
        cw_privileged install -m 644 "$work/source" /etc/apt/sources.list.d/github-cli.list || exit 1
    fi
)
cw_install_nvm() (
    set -e
    state=0
    cw_load_nvm || state=$?
    [ "$state" -ne 0 ] || exit 0
    [ "$state" -eq 1 ] || exit 1
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    case "$NVM_DIR" in /*) ;; *) cw_log FAIL "NVM_DIR deve ser absoluto."; exit 1 ;; esac
    case "$NVM_DIR/" in "$CW_ROOT/"*) cw_log FAIL 'NVM_DIR não pode ficar no clone.'; exit 1 ;; esac
    [ ! -e "$NVM_DIR" ] && [ ! -L "$NVM_DIR" ] || exit 1
    work=$(mktemp -d) || exit 1
    trap 'rm -rf "$work"' EXIT
    # Resolve stable release through GitHub HTTPS, then validate the fetched Git tag.
    url=$(curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --max-time 90 -o /dev/null -w '%{url_effective}' https://github.com/nvm-sh/nvm/releases/latest) || exit 1
    tag=${url##*/}
    [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
    git clone --quiet --depth 1 --branch "$tag" https://github.com/nvm-sh/nvm.git "$work/source" || exit 1
    git -C "$work/source" fsck --no-reflogs || exit 1
    [ "$(git -C "$work/source" rev-parse HEAD)" = "$(git -C "$work/source" rev-parse "$tag^{commit}")" ] || exit 1
    /bin/bash -n "$work/source/install.sh" || exit 1
    cw_log INSTALL "NVM $tag (instalador oficial validado por tag e sintaxe; confiança em HTTPS/GitHub)"
    mkdir -p "$NVM_DIR" || exit 1
    NODE_VERSION= NVM_ENV= PROFILE=/dev/null METHOD=git NVM_SOURCE="$work/source" NVM_INSTALL_VERSION="$tag" /bin/bash "$work/source/install.sh" || exit 1
    # The official installer uses a local clone; remove its temporary origin.
    git -C "$NVM_DIR" remote set-url origin https://github.com/nvm-sh/nvm.git || exit 1
)
