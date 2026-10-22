# Bash 3.2. Manifest data is validated against a closed, code-owned allowlist.
cw_df_safe() {
    local path=$1 part current=/
    case "$path" in /*) ;; *) return 1 ;; esac
    case "$path" in *$'\n'*|*$'\t'*|*'//'*) return 1 ;; esac
    path=${path#/}
    while [ -n "$path" ]; do
        part=${path%%/*}
        case "$part" in ''|.|..) return 1 ;; esac
        current=${current%/}/$part
        [ ! -L "$current" ] || return 1
        if [ "$path" = "$part" ]; then break; fi
        [ ! -e "$current" ] || [ -d "$current" ] || return 1
        path=${path#*/}
    done
}
cw_df_git_prefix() {
    local escaped=$source_file
    escaped=${escaped//\\/\\\\}
    escaped=${escaped//\"/\\\"}
    printf '# BEGIN config-workplace portable Git\n[include]\n    path = "%s"\n# END config-workplace portable Git\n' "$escaped"
}
cw_df_kind() {
    if [ "${policy:-symlink}" = git-include ]; then
        if [ -L "$destination" ] || { [ -e "$destination" ] && [ ! -f "$destination" ]; }; then
            printf conflict
        elif [ ! -e "$destination" ]; then printf absent
        elif cmp -s <(head -c "$(cw_df_git_prefix | wc -c | tr -d ' ')" "$destination") <(cw_df_git_prefix); then
            if [ -f "$source_file" ]; then printf correct; else printf broken-managed; fi
        elif grep -Fq 'config-workplace portable Git' "$destination"; then printf conflict
        else printf personal; fi
        return
    fi
    if [ -L "$destination" ]; then
        if [ "$(readlink "$destination")" = "$source_file" ]; then
            if [ -f "$source_file" ]; then printf correct; else printf broken-managed; fi
        elif [ -e "$destination" ]; then printf foreign-link; else printf broken-foreign; fi
    elif [ -f "$destination" ]; then
        if cmp -s "$destination" "$source_file"; then printf identical; else printf divergent; fi
    elif [ -e "$destination" ]; then printf conflict
    else printf absent; fi
}
# lstat identity plus content catches equal-byte replacements and chmod during approval.
# BSD and GNU stat have different interfaces; no readlink -f or GNU-only requirement.
cw_df_identity() {
    stat -f '%d:%i:%p:%u:%g:%l:%z:%m:%c' "$1" 2>/dev/null ||
        stat -c '%d:%i:%f:%u:%g:%h:%s:%Y:%Z' "$1" 2>/dev/null
}
cw_df_snapshot() {
    cw_df_kind
    if [ -e "$destination" ] || [ -L "$destination" ]; then
        cw_df_identity "$destination" || return 1
        if [ -L "$destination" ]; then readlink "$destination"
        elif [ -f "$destination" ]; then cksum < "$destination"; fi
    fi
}
cw_df_unchanged() {
    cw_df_safe "${destination%/*}" && cw_df_safe "$source_file" &&
        [ "$(cw_df_snapshot)" = "$before" ] || {
        cw_log FAIL 'Destino/caminho mudou durante operação; preservado'; return 1;
    }
}
# Only recognize the exact allowlisted absolute link; relatives remain conflicts.
cw_df_terminal_link() (
    policy=symlink
    df_home=$(CDPATH= cd -- "$HOME" && pwd -P) || exit 1
    repo=${CW_DOTFILES_REPO:-${XDG_DATA_HOME:-$df_home/.local/share}/config-workplace-dotfiles/repository}
    source_file="$repo/manifests/terminal/zshrc"
    destination=$(cw_df_destination terminal)
    [ "$1" = "$destination" ] || exit 1
    cw_df_safe "$source_file" && cw_df_safe "${destination%/*}" || exit 1
    [ "$(cw_df_kind)" = correct ]
)
cw_df_one() (
    set -eu
    umask 077
    action=$1; id=$2; dry=$3; approved=${4:-0}
    expected=${5:-}; expected_sum=${6:-}
    df_home=$(CDPATH= cd -- "$HOME" && pwd -P) || exit 1
    repo=${CW_DOTFILES_REPO:-${XDG_DATA_HOME:-$df_home/.local/share}/config-workplace-dotfiles/repository}
    cw_df_safe "$repo" || { cw_log FAIL 'Raiz do repositório insegura'; exit 1; }
    [ -d "$repo" ] || { cw_log REVIEW "Prepare um checkout permanente e configure CW_DOTFILES_REPO: $repo"; exit 1; }
    repo=$(CDPATH= cd -- "$repo" && pwd -P) || exit 1
    case "$repo/" in "$df_home/.local/share/config-workplace/"*) cw_log FAIL 'Fonte não pode ficar na instalação substituível da CLI'; exit 1 ;; esac
    cw_df_entry "$id" || exit 1
    source_file="$repo/$relative"
    destination=$(cw_df_destination "$id") || exit 1
    state=${XDG_STATE_HOME:-$df_home/.local/state}/config-workplace/dotfiles
    cw_df_safe "$source_file" && cw_df_safe "${destination%/*}" && cw_df_safe "$state" || { cw_log FAIL 'Caminho ou ancestral simbólico não permitido'; exit 1; }
    case "$state/" in "$repo/"*|"$CW_ROOT/"*) cw_log FAIL 'Estado/backups devem ficar fora do repositório'; exit 1 ;; esac
    for journal in "$state"/operation.*/journal; do
        [ -f "$journal" ] || continue
        if [ "$(tail -n 1 "$journal")" != complete ]; then
            cw_log REVIEW "Journal incompleto preservado; revise antes de continuar: $journal"
        fi
    done
    kind=$(cw_df_kind)
    before=$(cw_df_snapshot) || exit 1
    if [ "$approved" -eq 1 ]; then
        [ "$before" = "$expected" ] || { cw_log FAIL 'Destino mudou após plano; preservado'; exit 1; }
        if [ "$action" = link ]; then [ "$(cksum < "$source_file")" = "$expected_sum" ] || exit 1; fi
    fi
    cw_log "$kind" "$id: $destination -> $source_file ($policy)"
    if [ -e "$state/lock" ] || [ -L "$state/lock" ]; then cw_log REVIEW "Operação pendente/lock residual: $state/lock; revise journals antes de remover o lock vazio"; exit 1; fi
    if [ "$action" = status ]; then [ "$kind" = correct ]; exit $?; fi
    if [ "$action" = link ]; then
        [ -f "$source_file" ] || { cw_log FAIL 'Fonte ausente'; exit 1; }
        case "$kind" in
            correct) exit 0 ;;
            absent|identical|personal) ;;
            *) cw_log REVIEW 'Conflito preservado. Revise/mescle manualmente em área local privada; nunca importe secrets. Links de terceiros não são substituídos.'; exit 1 ;;
        esac
        source_sum=$(cksum < "$source_file") || exit 1
        if [ "$policy" = git-include ]; then
            cw_log PLAN 'Adicionar include portátil no início de .gitconfig; identidade e preferências pessoais posteriores têm precedência.'
        else cw_log REVIEW 'Criar link do fragmento aprovado. Startup, tema e plugins pessoais não serão editados; ativação deve ser revisada manualmente.'; fi
    else
        case "$kind" in correct|broken-managed) ;; absent|personal) exit 0 ;; *) cw_log REVIEW 'Não é link gerenciado; preservado'; exit 1 ;; esac
        if [ "$policy" = git-include ]; then
            cw_log PLAN 'Remover somente o bloco include exato no início de .gitconfig; preservar os demais bytes.'
        else cw_log REVIEW 'Remover somente este link; conteúdo da fonte e backups serão preservados. O fragmento deixará de ser carregado.'; fi
    fi
    [ "$dry" -eq 0 ] || exit 0
    [ "$approved" -eq 1 ] || cw_confirm || { cw_log SKIP 'Operação recusada'; exit 0; }
    cw_df_safe "${destination%/*}" && cw_df_safe "$state" && cw_df_safe "$source_file" || exit 1
    cw_df_unchanged || exit 1
    if [ "$action" = link ]; then [ "$(cksum < "$source_file")" = "$source_sum" ] || exit 1; fi
    mkdir -p "$state" || exit 1
    mkdir "$state/lock" 2>/dev/null || exit 1
    transaction=
    work=
    cleanup() {
        result=$?
        trap - EXIT
        if [ -n "$transaction" ] && [ "$result" -ne 0 ]; then
            printf 'incomplete\n' >> "$transaction/journal"
            cw_log REVIEW "Falha: artefatos preservados em $transaction. Recuperação manual; nenhuma restauração destrutiva automática."
        fi
        if [ -n "$work" ] && [ "$result" -eq 0 ]; then rmdir "$work" || :; fi
        rmdir "$state/lock" || :
        exit "$result"
    }
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' HUP TERM
    cw_df_unchanged || exit 1
    transaction=$(mktemp -d "$state/operation.XXXXXX") || exit 1
    printf 'action\t%s\nsource\t%s\ndestination\t%s\nbefore\t%s\n' "$action" "$source_file" "$destination" "$kind" > "$transaction/journal" || exit 1
    printf 'id\t%s\npolicy\t%s\nsnapshot\n%s\n' "$id" "$policy" "$before" >> "$transaction/journal" || exit 1
    if [ "$kind" = identical ] || { [ "$policy" = git-include ] && [ -f "$destination" ]; }; then
        cp -p "$destination" "$transaction/original" || exit 1
        cmp -s "$destination" "$transaction/original" || exit 1
        cw_log BACKUP "$transaction/original"
    elif [ "$action" = unlink ]; then
        cp -P "$destination" "$transaction/original-link" || exit 1
    fi
    printf 'prepared\n' >> "$transaction/journal" || exit 1
    cw_df_safe "${destination%/*}" && cw_df_safe "$source_file" || exit 1
    cw_df_unchanged || exit 1
    if [ "$policy" = git-include ]; then
        cw_df_git_apply || exit 1
    elif [ "$action" = link ]; then
        [ "$(cksum < "$source_file")" = "$source_sum" ] || exit 1
        mkdir -p "${destination%/*}" || exit 1
        work=$(mktemp -d "${destination%/*}/.cw-dotfiles.XXXXXX") || exit 1
        printf 'staging\t%s\n' "$work" >> "$transaction/journal" || exit 1
        ln -s "$source_file" "$work/link" || exit 1
        [ "$(readlink "$work/link")" = "$source_file" ] || exit 1
        if [ "$kind" = identical ]; then
            # Probe semantics in private staging, never against a personal path.
            # -T (GNU) / -h (BSD) prevent following a destination symlink to a dir.
            printf probe > "$work/probe-target"
            ln -s "$source_file" "$work/probe-link" || exit 1
            if mv -fT "$work/probe-link" "$work/probe-target" 2>/dev/null; then
                move_option=-fT
            elif [ -L "$work/probe-link" ] && mv -fh "$work/probe-link" "$work/probe-target" 2>/dev/null; then
                move_option=-fh
            else
                cw_log FAIL 'Substituição segura indisponível; original preservado'; exit 1
            fi
            [ -L "$work/probe-target" ] || exit 1
            rm "$work/probe-target" || exit 1
            cw_df_unchanged || exit 1
            cmp -s "$destination" "$transaction/original" || exit 1
            [ "$(cksum < "$source_file")" = "$source_sum" ] || exit 1
            printf 'replacing\n' >> "$transaction/journal" || exit 1
            # Same filesystem rename: never unlink the original first.
            mv "$move_option" "$work/link" "$destination" || exit 1
        else
            cw_df_unchanged || exit 1
            # Do not follow a destination symlink introduced since the check.
            # GNU -T also refuses real directories; BSD -h has a documented gap.
            case "$(uname -s)" in
                Darwin|FreeBSD) ln -sh "$source_file" "$destination" || exit 1 ;;
                Linux) ln -sT "$source_file" "$destination" || exit 1 ;;
                *) cw_log FAIL 'Plataforma sem criação de link validada'; exit 1 ;;
            esac
            rm "$work/link" || exit 1
        fi
        [ -L "$destination" ] && [ "$(readlink "$destination")" = "$source_file" ] || exit 1
    else
        [ -L "$destination" ] && [ "$(readlink "$destination")" = "$source_file" ] || exit 1
        rm "$destination" || exit 1
    fi
    printf 'complete\n' >> "$transaction/journal" || exit 1
    cw_log DONE "$action: $transaction"
)

# Destination tokens are resolved here, never expanded/evaluated from manifest text.
cw_df_destination() {
    local df_home
    df_home=$(CDPATH= cd -- "$HOME" && pwd -P) || return 1
    case "$1" in
        terminal) printf '%s/.config/config-workplace-terminal/zshrc\n' "${df_home:-$HOME}" ;;
        git) printf '%s/.gitconfig\n' "${df_home:-$HOME}" ;;
        vscode)
            case "${cw_os:-$(uname -s)}" in
                macos|Darwin) printf '%s/Library/Application Support/Code/User/settings.json\n' "${df_home:-$HOME}" ;;
                *) printf '%s/Code/User/settings.json\n' "${XDG_CONFIG_HOME:-${df_home:-$HOME}/.config}" ;;
            esac ;;
        *) return 1 ;;
    esac
}
cw_df_allowed() {
    case "$1" in
        'terminal|manifests/terminal/zshrc|terminal|macos,ubuntu|symlink'|\
        'git|manifests/git.config|git|macos,ubuntu|git-include'|\
        'vscode|manifests/vscode-settings.json|vscode|macos,ubuntu|review-jsonc') return 0 ;;
        *) return 1 ;;
    esac
}
cw_df_manifest() {
    local id relative target systems policy description extra seen='|'
    local manifest="$CW_ROOT/manifests/dotfiles.manifest"
    cw_df_safe "$manifest" && [ -f "$manifest" ] || return 1
    while IFS='|' read -r id relative target systems policy description extra || [ -n "$id" ]; do
        case "$id" in ''|'#'*) continue ;; esac
        case "$seen" in *"|$id|"*) return 1 ;; esac
        seen="$seen$id|"
        [ -n "$description" ] && [ -z "$extra" ] || return 1
        cw_df_allowed "$id|$relative|$target|$systems|$policy" || return 1
    done < "$manifest"
    [ "$seen" = '|terminal|git|vscode|' ]
}
cw_df_entry() {
    local entry_id target systems description extra
    while IFS='|' read -r entry_id relative target systems policy description extra; do
        if [ "$entry_id" = "$1" ]; then
            cw_df_allowed "$entry_id|$relative|$target|$systems|$policy"
            return $?
        fi
    done < "$CW_ROOT/manifests/dotfiles.manifest"
    return 1
}
# Preserve every byte of personal Git config, including its final newline state.
# Only our exact prefix is removed; arbitrary config is never sourced or evaluated.
cw_df_git_apply() {
    work=$(mktemp -d "${destination%/*}/.cw-dotfiles.XXXXXX") || return 1
    printf 'staging\t%s\n' "$work" >> "$transaction/journal" || return 1
    if [ -f "$destination" ]; then cp -p "$transaction/original" "$work/config" || return 1
    else : > "$work/config" || return 1; fi
    if [ "$action" = link ]; then
        cw_df_git_prefix > "$work/config" || return 1
        if [ -f "$transaction/original" ]; then cat "$transaction/original" >> "$work/config" || return 1; fi
        [ "$(cksum < "$source_file")" = "$source_sum" ] || return 1
    else
        dd if="$transaction/original" of="$work/config" bs=1 skip="$(cw_df_git_prefix | wc -c | tr -d ' ')" 2>/dev/null || return 1
    fi
    if [ "$kind" = absent ]; then
        cw_df_unchanged || return 1
        if [ "$action" = link ]; then [ "$(cksum < "$source_file")" = "$source_sum" ] || return 1; fi
        # Hard-link publication fails if any destination appeared; never overwrites.
        case "$(uname -s)" in
            Darwin) ln -h "$work/config" "$destination" || return 1 ;;
            Linux) ln -T "$work/config" "$destination" || return 1 ;;
            *) return 1 ;;
        esac
        [ "$(cw_df_identity "$work/config")" = "$(cw_df_identity "$destination")" ] || return 1
        rm "$work/config" || return 1
    else
        printf probe > "$work/probe-target" || return 1
        printf probe > "$work/probe-file" || return 1
        if mv -fT "$work/probe-file" "$work/probe-target" 2>/dev/null; then move_option=-fT
        elif [ -f "$work/probe-file" ] && mv -fh "$work/probe-file" "$work/probe-target" 2>/dev/null; then move_option=-fh
        else return 1; fi
        rm "$work/probe-target" || return 1
        cw_df_unchanged || return 1
        if [ "$action" = link ]; then [ "$(cksum < "$source_file")" = "$source_sum" ] || return 1; fi
        cmp -s "$destination" "$transaction/original" || return 1
        printf 'replacing\n' >> "$transaction/journal" || return 1
        mv "$move_option" "$work/config" "$destination" || return 1
    fi
    [ -f "$destination" ] && [ ! -L "$destination" ] || return 1
    if [ "$action" = link ]; then [ "$(cw_df_kind)" = correct ] || return 1; fi
}
cw_df_vscode() {
    local destination
    destination=$(cw_df_destination vscode) || return 1
    cw_df_safe "$destination" && { [ ! -e "$destination" ] || [ -f "$destination" ]; } || { cw_log REVIEW "vscode: caminho externo/conflitante preservado: $destination"; return 1; }
    cw_log MANUAL "vscode: review-jsonc; $destination preservado. Sem symlink ou mesclagem neste comando."
    cw_log MANUAL 'Revise manifests/vscode-settings.json. A integração JSONC por chave permanece em initial dev, com Node, confirmação e backups próprios; extensões não são alteradas por dotfiles.'
}
cw_dotfiles() (
    set -eu
    umask 077
    action=${1:-help}; [ "$#" -eq 0 ] || shift
    dry=0; selection=; selected=(); snapshots=(); sums=()
    case "$action" in
        help|--help)
            printf '%s\n' 'Uso: workspace dotfiles {list|status|link|unlink} [--all | --only terminal|git|vscode] [--dry-run]' \
                'Sem seleção: link/unlink/status preservam o alvo legado terminal-fragment (alias de terminal).' \
                'list mostra todos. VS Code é revisão manual JSONC, sem escrita.' \
                'Fonte: CW_DOTFILES_REPO ou ~/.local/share/config-workplace-dotfiles/repository (checkout permanente revisado).'
            exit 0 ;;
        list|status|link|unlink) ;;
        *) cw_log FAIL 'Subcomando dotfiles inválido'; exit 2 ;;
    esac
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --dry-run) dry=1 ;;
            --all) [ -z "$selection" ] || exit 2; selection=all ;;
            --only)
                [ -z "$selection" ] && [ "$#" -ge 2 ] || exit 2
                shift; selection=$1
                case "$selection" in terminal|git|vscode) ;; terminal-fragment) selection=terminal ;; *) exit 2 ;; esac ;;
            *) cw_log FAIL "Opção inválida: $1"; exit 2 ;;
        esac
        shift
    done
    cw_df_manifest || { cw_log FAIL 'Manifesto inválido: schema, IDs, ordem ou allowlist não aprovados'; exit 1; }
    if [ "$action" = list ]; then
        while IFS='|' read -r id relative target systems policy description; do
            case "$id" in ''|'#'*) continue ;; esac
            if [ -z "$selection" ] || [ "$selection" = all ] || [ "$selection" = "$id" ]; then
                printf '%s | %s | %s | %s | %s | %s\n' "$id" "$relative" "$(cw_df_destination "$id")" "$systems" "$policy" "$description"
            fi
        done < "$CW_ROOT/manifests/dotfiles.manifest"
        exit 0
    fi
    case "$(uname -s)" in Darwin|Linux) ;; *) cw_log FAIL 'Plataforma não suportada'; exit 1 ;; esac
    if [ "$selection" = all ]; then selected=(terminal git vscode)
    else selected=("${selection:-terminal}"); fi
    df_home=$(CDPATH= cd -- "$HOME" && pwd -P) || exit 1
    repo=${CW_DOTFILES_REPO:-${XDG_DATA_HOME:-$df_home/.local/share}/config-workplace-dotfiles/repository}
    blocked=0; index=0
    # Snapshot before showing any confirmation; a conflict blocks the entire selection.
    for id in "${selected[@]}"; do
        if [ "$id" = vscode ]; then
            cw_df_vscode || blocked=1
            continue
        fi
        cw_df_entry "$id" || exit 1
        source_file="$repo/$relative"; destination=$(cw_df_destination "$id")
        cw_df_safe "$source_file" && cw_df_safe "${destination%/*}" || exit 1
        snapshots[$index]=$(cw_df_snapshot) || exit 1
        sums[$index]=
        if [ -f "$source_file" ]; then sums[$index]=$(cksum < "$source_file") || exit 1; fi
        cw_df_one "$action" "$id" 1 || blocked=1
        index=$((index + 1))
    done
    [ "$blocked" -eq 0 ] || exit 1
    [ "$action" != status ] && [ "$dry" -eq 0 ] || exit 0
    # Avoid confirmation/journals when the selected targets already match.
    pending=0; index=0
    for id in "${selected[@]}"; do
        [ "$id" != vscode ] || continue
        cw_df_entry "$id" || exit 1
        source_file="$repo/$relative"; destination=$(cw_df_destination "$id")
        kind=$(cw_df_kind)
        if [ "$action" = link ]; then [ "$kind" = correct ] || pending=1
        else case "$kind" in absent|personal) ;; *) pending=1 ;; esac; fi
    done
    [ "$pending" -eq 1 ] || exit 0
    cw_confirm || { cw_log SKIP 'Operação recusada'; exit 0; }
    index=0
    # Revalidate every selected file before the first write, not just the next one.
    for id in "${selected[@]}"; do
        [ "$id" != vscode ] || continue
        cw_df_entry "$id" || exit 1
        source_file="$repo/$relative"; destination=$(cw_df_destination "$id")
        before=${snapshots[$index]}
        cw_df_unchanged || exit 1
        if [ "$action" = link ]; then [ "$(cksum < "$source_file")" = "${sums[$index]}" ] || exit 1; fi
        index=$((index + 1))
    done
    index=0
    for id in "${selected[@]}"; do
        [ "$id" != vscode ] || continue
        # Stop on failure; retain earlier successes and all recovery artifacts.
        cw_df_one "$action" "$id" 0 1 "${snapshots[$index]}" "${sums[$index]}" || exit 1
        index=$((index + 1))
    done
)
