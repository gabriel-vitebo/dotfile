cw_install_vscode() (
    state=0; cw_vscode_probe || state=$?
    [ "$state" -ne 0 ] || exit 0
    [ "$state" -eq 1 ] || exit 1
    if [ "$cw_os" = macos ]; then
        cw_probe brew || { cw_log MANUAL 'Prepare Homebrew manualmente.'; exit 1; }
        HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1 brew install --cask visual-studio-code || exit 1
    else
        work=$(mktemp -d) || exit 1
        trap 'rm -rf "$work"' EXIT
        case "$cw_arch" in x86_64) arch=x64 ;; *) arch=arm64 ;; esac
        cw_fetch "https://update.code.visualstudio.com/latest/linux-deb-$arch/stable" > "$work/code.deb" || exit 1
        # Official HTTPS artifact; no existing APT source or signing key is overwritten.
        cw_privileged apt-get install --no-upgrade -y "$work/code.deb" || exit 1
    fi
    cw_vscode_probe
)
cw_code_launcher() (
    cw_vscode_probe || exit 1
    command -v code >/dev/null 2>&1 && exit 0
    case "$cw_code" in "$CW_ROOT/"*) exit 1 ;; esac
    destination="$HOME/.local/bin/code"
    cw_safe_destination "$destination" || exit 1
    [ ! -e "$destination" ] && [ ! -L "$destination" ] || { cw_log REVIEW "$destination existe; preservado."; exit 1; }
    cw_log PLAN "Criar $destination apontando ao aplicativo instalado: $cw_code"
    cw_confirm || exit 0
    cw_local_path || exit 0
    mkdir -p "$HOME/.local/bin" && ln -s "$cw_code" "$destination" || exit 1
    "$destination" --version
)
