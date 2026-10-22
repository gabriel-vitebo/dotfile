# Uses the shared detect-before-install package adapter (APT --no-upgrade / brew).
cw_terminal_install_omz() (
    dir=$1
    theme=$(cw_terminal_preferred_theme) || exit 1
    state=0; cw_terminal_omz_probe "$dir" || state=$?
    [ "$state" -ne 0 ] || exit 0
    [ "$state" -eq 1 ] || exit 1
    cw_safe_destination "$dir" || exit 1
    cw_probe git && cw_probe zsh || exit 1
    mkdir -p "${dir%/*}" || exit 1
    work=$(mktemp -d "${dir%/*}/.cw-omz.XXXXXX") || exit 1
    trap 'rm -rf "$work"' EXIT
    # No upstream installer: it must not rename .zshrc or call chsh.
    git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$work/omz" || exit 1
    git -C "$work/omz" fsck --no-reflogs || exit 1
    cw_terminal_omz_probe "$work/omz" || exit 1
    cw_terminal_asset_probe "$work/omz/themes/$theme.zsh-theme" || exit 1
    cw_terminal_asset_probe "$work/omz/plugins/git/git.plugin.zsh" || exit 1
    cw_log CHECK "Oh My Zsh commit $(git -C "$work/omz" rev-parse HEAD) (HTTPS oficial; sem assinatura independente)"
    [ ! -e "$dir" ] && [ ! -L "$dir" ] || exit 1
    mv "$work/omz" "$dir" || exit 1
    cw_terminal_omz_probe "$dir"
)

# Fill only absent built-in assets; never update a partial framework in place.
cw_terminal_install_asset() (
    destination=$1
    asset=$2
    cw_safe_destination "$destination" || exit 1
    [ ! -e "$destination" ] && [ ! -L "$destination" ] || exit 0
    cw_probe git && cw_probe zsh || exit 1
    work=$(mktemp -d) || exit 1
    work=$(cd "$work" && pwd -P) || exit 1
    trap 'rm -rf "$work"' EXIT
    git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$work/source" || exit 1
    git -C "$work/source" fsck --no-reflogs || exit 1
    cw_terminal_asset_probe "$work/source/$asset" || exit 1
    # Same diff/approval/backup protection as other managed files.
    cw_terminal_file "$destination" "$work/source/$asset"
)
