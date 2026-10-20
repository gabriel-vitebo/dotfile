# Read configuration as data. Never source a user's startup files during probing.
cw_terminal_theme() {
    local file=$1
    [ -f "$file" ] || return 1
    # Conservative: only the known captured configuration can be identified.
    [ "$(grep -Ec '^[[:space:]]*(export[[:space:]]+)?ZSH_THEME=' "$file")" -eq 1 ] || return 1
    grep -Eq '^[[:space:]]*ZSH_THEME=["]?robbyrussell["]?[[:space:]]*$' "$file" || return 1
    grep -Eq '^[[:space:]]*(source|\.) .*oh-my-zsh.sh' "$file" || return 1
    if grep -Eq '^[^#]*(starship|p10k|powerlevel|PROMPT=|RPROMPT=)' "$file"; then return 1; fi
    printf '%s\n' robbyrussell
}
cw_terminal_omz_probe() {
    local dir=$1 file
    [ -e "$dir" ] || [ -L "$dir" ] || return 1
    cw_safe_destination "$dir" || return 2
    for file in oh-my-zsh.sh lib/git.zsh lib/theme-and-appearance.zsh; do
        [ -s "$dir/$file" ] || return 2
        command -v zsh >/dev/null || return 2
        zsh -f -n "$dir/$file" >/dev/null 2>&1 || return 2
    done
}
cw_terminal_asset_probe() {
    cw_safe_destination "$1" || return 2
    [ -e "$1" ] || [ -L "$1" ] || return 1
    [ -f "$1" ] && [ -s "$1" ] || return 2
    command -v zsh >/dev/null && zsh -f -n "$1" >/dev/null 2>&1 || return 2
}
cw_terminal_report() {
    case "$2" in
        0) cw_log SKIP "$1: funcional/sintaxe válida; preservar versão existente" ;;
        1) cw_log INSTALL "$1: ausente" ;;
        *) cw_log REVIEW "$1: existente, requer revisão; não substituir" ;;
    esac
}
