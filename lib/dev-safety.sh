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
# Probe real startup files, rather than matching shell source text. A clean
# environment prevents the installer's transient PATH from hiding missing setup.
# Startup code runs as the user, just as when opening a terminal.
cw_path_probe() {
    local mode=$1 result
    result=$(env -i HOME="$HOME" USER="${USER:-}" LOGNAME="${LOGNAME:-}" \
        SHELL="$path_shell" TERM=dumb PATH=/usr/bin:/bin:/usr/sbin:/sbin \
        "${path_zdot_env[@]}" "$path_shell" "$mode" '
        case ":$PATH:" in *":$HOME/.local/bin:"*) printf "\nCW_PATH_OK\n" ;; esac
        ' </dev/null 2>/dev/null) || return 1
    case "$result" in *$'\nCW_PATH_OK'*) return 0 ;; *) return 1 ;; esac
}
cw_path_append() {
    local profile=$1 reason=$2 before= backup block
    # Only personal files: never edit /etc, corporate directories or links.
    case "$profile" in
        "$HOME"/*) ;;
        /etc/*|/usr/*|/opt/*|/var/*|/System/*|/Library/*)
            cw_log REVIEW "Configuração global/corporativa preservada: $profile"; return 1 ;;
        *)
            # ZDOTDIR can live outside HOME, but must be a personal directory.
            [ -O "${profile%/*}" ] || { cw_log REVIEW "Diretório não pertence ao usuário: ${profile%/*}"; return 1; } ;;
    esac
    cw_safe_destination "$profile" || return 1
    [ ! -e "$profile" ] || { [ -f "$profile" ] && [ -O "$profile" ]; } || return 1
    [ -d "${profile%/*}" ] || { cw_log REVIEW "Diretório ausente: ${profile%/*}"; return 1; }
    [ ! -f "$profile" ] || before=$(cksum < "$profile")
    block='# >>> config-workplace PATH >>>
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
# <<< config-workplace PATH <<<'
    if [ -f "$profile" ] && { grep -Fq '# >>> config-workplace PATH >>>' "$profile" ||
        grep -Fq '.local/bin' "$profile"; }; then
        cw_log REVIEW "Referência a PATH existente sem efeito confirmado em $profile; revise o fluxo de startup manualmente."
        return 1
    fi
    cw_log PLAN "$profile: $reason. Acrescentar ao final:"
    printf '%s\n' "$block"
    cw_confirm || { cw_log SKIP "Alteração recusada: $profile"; return 1; }
    cw_safe_destination "$profile" || return 1
    if [ -n "$before" ]; then
        [ -f "$profile" ] && [ "$(cksum < "$profile")" = "$before" ] || return 1
        backup=$(mktemp "$profile.config-workplace-backup.XXXXXX") || return 1
        cp -p "$profile" "$backup" || return 1
        cw_log BACKUP "$backup"
    else
        [ ! -e "$profile" ] && [ ! -L "$profile" ] || return 1
    fi
    printf '\n%s\n' "$block" >> "$profile" || return 1
}
cw_local_path() {
    local path_shell=${SHELL:-} shell_name login rc mode failed=0 effective
    local -a path_zdot_env=()
    shell_name=${path_shell##*/}
    case "$shell_name" in bash|zsh) ;; *) cw_log REVIEW 'Shell não suportado; configure ~/.local/bin manualmente.'; return 1 ;; esac
    [ -x "$path_shell" ] || { cw_log REVIEW "Shell indisponível: $path_shell"; return 1; }
    if [ "$shell_name" = bash ]; then
        rc="$HOME/.bashrc"
        if [ -e "$HOME/.bash_profile" ] || [ -L "$HOME/.bash_profile" ]; then login="$HOME/.bash_profile"
        elif [ -e "$HOME/.bash_login" ] || [ -L "$HOME/.bash_login" ]; then login="$HOME/.bash_login"
        else login="$HOME/.profile"; fi
    else
        [ -z "${ZDOTDIR+x}" ] || path_zdot_env=("ZDOTDIR=$ZDOTDIR")
        # .zshenv may select a different ZDOTDIR from the inherited value.
        effective=$(env -i HOME="$HOME" PATH=/usr/bin:/bin:/usr/sbin:/sbin \
            "${path_zdot_env[@]}" "$path_shell" -c 'printf "\nCW_ZDOT=%s\n" "${ZDOTDIR:-$HOME}"' </dev/null 2>/dev/null) || return 1
        effective=${effective##*$'\nCW_ZDOT='}
        case "$effective" in /*) ;; *) cw_log REVIEW 'ZDOTDIR efetivo não é absoluto; integração manual.'; return 1 ;; esac
        rc="$effective/.zshrc"; login="$effective/.zprofile"
    fi
    cw_log CHECK "Shell $path_shell; login: $login; interativo: $rc. Verificando novas sessões."
    # Repair interactive startup first: login configurations often already source
    # it, so reprobe login afterwards to avoid a redundant second modification.
    if ! cw_path_probe -ic; then
        cw_path_append "$rc" 'PATH ausente no shell interativo não-login' || failed=1
    fi
    # Noninteractive login matters too (bash -lc / zsh -lc).
    if ! cw_path_probe -lc || ! cw_path_probe -lic; then
        cw_path_append "$login" 'PATH ausente no shell login' || failed=1
    fi
    for mode in -ic -lc -lic; do
        if ! cw_path_probe "$mode"; then
            cw_log REVIEW "PATH ainda ausente em $path_shell $mode; revise o startup manualmente."
            failed=1
        fi
    done
    [ "$failed" -eq 0 ] || return 1
    cw_log OK 'PATH verificado em novas sessões login e interativas não-login.'
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
