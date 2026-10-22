. "$CW_ROOT/lib/dotfiles.sh"
cw_terminal_render_bootstrap() {
    local theme
    theme=$(cw_terminal_preferred_theme) || return 1
    printf 'export ZSH=%q\n' "$omz"
    sed "s/__CW_PREFERRED_THEME__/$theme/" "$CW_ROOT/manifests/terminal/bootstrap.zsh"
}
# Compare using streams in dry-run: no temporary files, cache or log writes.
cw_terminal_file() (
    destination=$1
    source_file=$2
    mode=${3:-copy}
    if cw_df_terminal_link "$destination"; then
        cw_log SKIP "$destination: link gerenciado; revisar fonte com dotfiles, sem escrita pelo terminal"
        exit 0
    fi
    cw_safe_destination "$destination" || exit 0
    [ ! -e "$destination" ] || [ -f "$destination" ] || { cw_log REVIEW "$destination não é arquivo regular"; exit 0; }
    render() {
        if [ "$mode" = startup ]; then
            printf '%s\n' '# >>> config-workplace terminal >>>' \
                '[[ ! -r "$HOME/.config/config-workplace-terminal/zshrc" ]] || source "$HOME/.config/config-workplace-terminal/zshrc"' \
                '# <<< config-workplace terminal <<<'
            [ ! -f "$destination" ] || cat "$destination"
        elif [ "$mode" = framework ]; then
            cw_terminal_render_bootstrap
        else cat "$source_file"; fi
    }
    if [ "$mode" = startup ] && [ -f "$destination" ]; then
        if grep -Fqx '# >>> config-workplace terminal >>>' "$destination"; then
            if [ "$(grep -Fc '# >>> config-workplace terminal >>>' "$destination")" -eq 1 ] &&
               head -n 3 "$destination" | cmp -s - <(printf '%s\n' '# >>> config-workplace terminal >>>' \
                '[[ ! -r "$HOME/.config/config-workplace-terminal/zshrc" ]] || source "$HOME/.config/config-workplace-terminal/zshrc"' \
                '# <<< config-workplace terminal <<<'); then cw_log SKIP "$destination: bloco já aplicado"
            else cw_log REVIEW "$destination: bloco modificado/duplicado; revisar manualmente"; fi
            exit 0
        fi
        # Do not layer a second framework over an arbitrary existing startup.
        if grep -Eq '^[[:space:]]*[^#]*(source|(^|[ ;])\.|ZSH|plugins=|PROMPT|starship|p10k|eval|exec|return|exit)'  "$destination"; then
            cw_log REVIEW "$destination: inicialização local preservada; integração manual necessária (não executar dois frameworks)"
            exit 0
        fi
    fi
    if [ -f "$destination" ] && cmp -s "$destination" <(render); then cw_log SKIP "$destination: idêntico"; exit 0; fi
    old=/dev/null; [ ! -f "$destination" ] || old=$destination
    cw_log REVIEW "$destination: diff proposto"
    diff -u "$old" <(render) || [ "$?" -eq 1 ] || exit 1
    [ "$dry" -eq 0 ] || exit 0
    before=absent; [ ! -f "$destination" ] || before=$(cksum < "$destination")
    cw_confirm || { cw_log SKIP "$destination: recusado"; exit 0; }
    cw_safe_destination "$destination" || exit 1
    now=absent; [ ! -f "$destination" ] || now=$(cksum < "$destination")
    [ "$before" = "$now" ] || { cw_log REVIEW 'Arquivo mudou durante confirmação'; exit 1; }
    mkdir -p "${destination%/*}" || exit 1
    lock="$destination.config-workplace-lock"
    mkdir "$lock" 2>/dev/null || exit 1
    work=
    trap 'rm -f "$work"; rmdir "$lock"' EXIT
    work=$(mktemp "$destination.tmp.XXXXXX") || exit 1
    render > "$work" || exit 1
    zsh -f -n "$work" || exit 1
    if [ -f "$destination" ]; then
        backup=$(mktemp "$destination.config-workplace-backup.XXXXXX") || exit 1
        cp -p "$destination" "$backup" || exit 1
        cw_log BACKUP "$backup"
        cp -p "$destination" "$work" || exit 1
        render > "$work" || exit 1
    fi
    cw_safe_destination "$destination" || exit 1
    now=absent; [ ! -f "$destination" ] || now=$(cksum < "$destination")
    [ "$before" = "$now" ] || { cw_log REVIEW "Arquivo mudou durante aplicação"; exit 1; }
    mv "$work" "$destination" || exit 1
    cw_log CONFIGURED "$destination"
)

# Existing startup files are never rewritten by the bootstrap. Even arbitrary
# shell code is treated as data; a separate candidate is offered for review.
cw_terminal_bootstrap() {
    local preferred="$CW_ROOT/manifests/terminal/startup.zsh"
    if [ -e "$rc" ] || [ -L "$rc" ]; then
        if cmp -s "$rc" "$preferred"; then
            cw_log SKIP 'Startup padrão já instalado'
        else
            cw_log REVIEW "Startup pessoal preservado: $rc. Diferenças para o padrão do projeto:"
            diff -u "$rc" "$preferred" || [ "$?" -eq 1 ] || return 1
            cw_log PLAN 'Aprovar salvar startup proposto em arquivo separado para integração manual? O .zshrc pessoal permanece intacto.'
            if [ "$dry" -eq 1 ] || cw_confirm; then
                cw_terminal_file "$bootstrap" "$CW_ROOT/manifests/terminal/bootstrap.zsh" framework || return 1
                cw_terminal_file "$HOME/.config/config-workplace-terminal/startup-proposed.zsh" "$preferred" || return 1
                cw_log MANUAL 'Revise startup-proposed.zsh e integre pela fonte dos seus dotfiles; tema/plugins existentes preservados.'
            else cw_log SKIP 'Proposta recusada; startup preservado'; fi
            return 0
        fi
    fi
    cw_terminal_file "$bootstrap" "$CW_ROOT/manifests/terminal/bootstrap.zsh" framework || return 1
    # Approval may have been declined. Never activate a missing/divergent payload.
    if [ "$dry" -eq 1 ] || cmp -s "$bootstrap" <(cw_terminal_render_bootstrap); then
        if [ ! -e "$rc" ] && [ ! -L "$rc" ]; then
            if [ "$dry" -eq 1 ] || cw_df_terminal_link "$payload" ||
                { cw_safe_destination "$payload" && cmp -s "$payload" "$CW_ROOT/manifests/terminal/zshrc"; }; then
                cw_terminal_file "$rc" "$preferred" || return 1
            else
                cw_log REVIEW 'Startup adiado: fragmento ausente, divergente ou em conflito; reexecute após revisão.'
            fi
        fi
    fi
}
