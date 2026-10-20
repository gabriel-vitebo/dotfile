# Refuse symbolic ancestors and destinations in the source/installed payload.
cw_safe_destination() {
    local current=$1
    case "$current" in /*) ;; *) return 1 ;; esac
    case "/$current/" in */../*|*/./*) return 1 ;; esac
    case "$current/" in "$CW_ROOT/"*) cw_log REVIEW 'Destino depende do clone; preservado.'; return 1 ;; esac
    while [ "$current" != / ]; do
        [ ! -L "$current" ] || { cw_log REVIEW "Link preservado: $current"; return 1; }
        current=${current%/*}; [ -n "$current" ] || current=/
    done
}
cw_local_path() {
    local profile= line='export PATH="$HOME/.local/bin:$PATH"' backup shell_name=${SHELL:-}
    case "${shell_name##*/}" in
        zsh) profile="${ZDOTDIR:-$HOME}/.zprofile" ;;
        bash)
            if [ -f "$HOME/.bash_profile" ]; then profile="$HOME/.bash_profile"
            elif [ -f "$HOME/.bash_login" ]; then profile="$HOME/.bash_login"
            else profile="$HOME/.profile"; fi ;;
        *) cw_log REVIEW 'Shell não suportado; configure ~/.local/bin no PATH de novas sessões e reexecute.'; return 1 ;;
    esac
    cw_safe_destination "$profile" || return 1
    [ ! -e "$profile" ] || [ -f "$profile" ] || return 1
    if [ -f "$profile" ] && grep -Fqx "$line" "$profile"; then return 0; fi
    cw_log PLAN "Adicionar a $profile: $line (necessário em nova sessão login)"
    cw_confirm || return 1
    if [ -f "$profile" ]; then
        backup=$(mktemp "$profile.config-workplace-backup.XXXXXX") || return 1
        cp -p "$profile" "$backup" || return 1
        cw_log BACKUP "$backup"
    fi
    printf '\n%s\n' "$line" >> "$profile"
}
