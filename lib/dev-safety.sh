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

# NVM startup is self-contained: no reference to the CLI payload or source clone.
cw_nvm_shell_plan() {
    nvm_startup_pending=0
    nvm_startup_review=1
    local shell_name=${SHELL:-} existing= profile
    shell_name=${shell_name##*/}
    case "$shell_name" in
        bash) nvm_startup_file="$HOME/.bashrc" ;;
        zsh) nvm_startup_file="${ZDOTDIR:-$HOME}/.zshrc" ;;
        *) cw_log REVIEW "Shell ${SHELL:-desconhecido} não suportado para NVM."; return 0 ;;
    esac
    cw_log CHECK "Shell $shell_name; startup NVM: $nvm_startup_file"
    cw_safe_destination "$nvm_startup_file" || return 0
    [ ! -e "$nvm_startup_file" ] || [ -f "$nvm_startup_file" ] || { cw_log REVIEW 'Startup não é arquivo regular.'; return 0; }
    case "${NVM_DIR:-$HOME/.nvm}" in /*) ;; *) cw_log REVIEW 'NVM_DIR deve ser absoluto.'; return 0 ;; esac
    cw_safe_destination "${NVM_DIR:-$HOME/.nvm}" || return 0
    # printf %q is understood by both Bash 3.2 and Zsh, including paths with spaces.
    nvm_startup_block=$(printf '%s\n' '# >>> config-workplace NVM >>>';
        printf 'export NVM_DIR=%q\n' "${NVM_DIR:-$HOME/.nvm}";
        printf '%s\n' 'if ! command -v nvm >/dev/null 2>&1; then' '    [ ! -s "$NVM_DIR/nvm.sh" ] || . "$NVM_DIR/nvm.sh"' 'fi' '# <<< config-workplace NVM <<<')
    if [ -f "$nvm_startup_file" ]; then
        existing=$(cat "$nvm_startup_file")
        if [ "$(grep -c '^# >>> config-workplace NVM >>>$' "$nvm_startup_file" || :)" = 1 ] &&
           [ "$(grep -c '^# <<< config-workplace NVM <<<$' "$nvm_startup_file" || :)" = 1 ] &&
           ! sed '/^# >>> config-workplace NVM >>>$/,/^# <<< config-workplace NVM <<<$/d' "$nvm_startup_file" | grep -Eiq 'nvm|NVM_DIR' &&
           [ "$(sed -n '/^# >>> config-workplace NVM >>>$/,/^# <<< config-workplace NVM <<<$/p' "$nvm_startup_file")" = "$nvm_startup_block" ]; then
            nvm_startup_review=0
            cw_log SKIP 'Integração NVM gerenciada já configurada.'; return 0
        fi
        if grep -Eiq 'nvm|NVM_DIR' "$nvm_startup_file"; then
            cw_log REVIEW 'Integração NVM existente não confirmada; startup preservado, sem duplicar.'; return 0
        fi
    fi
    nvm_startup_before=
    [ ! -f "$nvm_startup_file" ] || nvm_startup_before=$(cksum < "$nvm_startup_file")
    nvm_startup_existed=0; [ ! -f "$nvm_startup_file" ] || nvm_startup_existed=1
    nvm_startup_pending=1
    nvm_startup_review=0
    cw_log PLAN "Acrescentar bloco NVM a $nvm_startup_file (confirmação separada):"
    printf '%s\n' "$nvm_startup_block"
}
cw_nvm_shell_apply() {
    [ "${nvm_startup_pending:-0}" -eq 1 ] || return 0
    local backup
    cw_log PLAN "Arquivo: $nvm_startup_file"
    printf '%s\n' "$nvm_startup_block"
    cw_confirm || { cw_log SKIP 'Integração NVM recusada; startup preservado.'; return 0; }
    cw_safe_destination "$nvm_startup_file" || return 1
    if [ "$nvm_startup_existed" -eq 1 ]; then
        [ -f "$nvm_startup_file" ] && [ "$(cksum < "$nvm_startup_file")" = "$nvm_startup_before" ] || { cw_log REVIEW 'Startup mudou após o plano.'; return 1; }
        backup=$(mktemp "$nvm_startup_file.config-workplace-backup.XXXXXX") || return 1
        cp -p "$nvm_startup_file" "$backup" || return 1
        cw_log BACKUP "$backup"
    else
        [ ! -e "$nvm_startup_file" ] && [ ! -L "$nvm_startup_file" ] || return 1
    fi
    printf '\n%s\n' "$nvm_startup_block" >> "$nvm_startup_file" || return 1
    cw_log CONFIGURED 'NVM persistente; abra um novo terminal interativo.'
}
