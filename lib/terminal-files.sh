# Compare using streams in dry-run: no temporary files, cache or log writes.
cw_terminal_file() (
    destination=$1
    source_file=$2
    mode=${3:-copy}
    cw_safe_destination "$destination" || exit 0
    [ ! -e "$destination" ] || [ -f "$destination" ] || { cw_log REVIEW "$destination não é arquivo regular"; exit 0; }
    render() {
        if [ "$mode" = startup ]; then
            printf '%s\n' '# >>> config-workplace terminal >>>' \
                '[[ ! -r "$HOME/.config/config-workplace-terminal/zshrc" ]] || source "$HOME/.config/config-workplace-terminal/zshrc"' \
                '# <<< config-workplace terminal <<<'
            [ ! -f "$destination" ] || cat "$destination"
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
