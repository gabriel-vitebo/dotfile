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
    # Try GNU first: GNU stat -f can emit filesystem data even when BSD syntax fails.
    stat -c '%d:%i:%f:%u:%g:%h:%s:%Y:%Z' "$1" 2>/dev/null ||
        stat -f '%d:%i:%p:%u:%g:%l:%z:%m:%c' "$1" 2>/dev/null
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
        sync) cw_dotfiles_sync "$@"; exit $? ;;
        init|doctor) cw_df_assist "$action" "$@"; exit $? ;;
        help|--help)
            printf '%s\n' 'Uso: workspace dotfiles {list|status|link|unlink} [--all | --only terminal|git|vscode] [--dry-run]' \
                '     workspace dotfiles init [--dry-run] | doctor' \
                '     workspace dotfiles sync [--dry-run | --status] (origin/main)' \
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

# Phase 5: approved upstream is deliberately not inferred from the CLI's remote.
cw_df_origin() { printf '%s\n' 'https://github.com/gabriel-vitebo/dotfile.git'; }
cw_df_reference() { printf '%s\n' e0ebd0226328b9a4551bd344fa8bb1bcc6126401; }
# Ignore personal Git configuration, injected GIT_* variables, hooks and templates.
# No command here loads shell configuration or executes repository scripts.
cw_df_git() {
    env -i PATH="$PATH" HOME="$df_home" GIT_CONFIG_GLOBAL=/dev/null \
        GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 GIT_OPTIONAL_LOCKS=0 \
        GIT_NO_LAZY_FETCH=1 GIT_NO_REPLACE_OBJECTS=1 \
        git -c core.hooksPath=/dev/null -c init.templateDir= \
        -c protocol.allow=never -c protocol.https.allow=always "$@"
}
cw_df_temporary() {
    case "$1/" in /tmp/*|/private/tmp/*|/var/tmp/*|/private/var/tmp/*|/var/folders/*|/private/var/folders/*) return 0 ;; esac
    if [ -n "${TMPDIR:-}" ]; then
        case "$1/" in "${TMPDIR%/}/"*) return 0 ;; esac
    fi
    return 1
}
cw_df_permanent() {
    local path=$1
    cw_df_safe "$path" || { cw_log FAIL "Caminho inseguro: $path"; return 1; }
    if cw_df_temporary "$path"; then cw_log REVIEW "Dependência de caminho temporário: $path"; return 1; fi
    case "$path/" in "$CW_ROOT/"*|"$df_home/.local/share/config-workplace/"*)
        cw_log FAIL "Checkout/estado dentro da CLI ou clone inicial: $path"; return 1 ;; esac
    case "$CW_ROOT/" in "$path/"*) cw_log FAIL 'Checkout/estado não pode conter a CLI'; return 1 ;; esac
}
cw_df_checkout_valid() {
    local file relative id source_file destination policy
    cw_df_safe "$repo/.git" && [ -d "$repo/.git" ] || {
        cw_log FAIL 'Destino ocupado: não é checkout independente (.git deve ser diretório)'; return 1;
    }
    # Worktrees, shared object stores and metadata symlinks can depend on a clone
    # that will be deleted. Do not repair or rewrite their metadata.
    [ -z "$(find "$repo/.git" -type l -print)" ] &&
        [ ! -e "$repo/.git/commondir" ] && [ ! -e "$repo/.git/objects/info/alternates" ] || {
        cw_log FAIL 'Metadados Git externos/compartilhados não permitidos'; return 1;
    }
    [ "$(cw_df_git -C "$repo" rev-parse --show-toplevel)" = "$repo" ] &&
        [ "$(cw_df_git -C "$repo" config --local --get remote.origin.url)" = "$(cw_df_origin)" ] || {
        cw_log FAIL 'Raiz ou origem diferente da origem aprovada; preservada'; return 1;
    }
    if cw_df_git -C "$repo" config --local --get-regexp '^(extensions\.partialclone|remote\..*\.promisor)$' >/dev/null; then
        cw_log FAIL 'Clone parcial pode depender de objetos remotos; preservado'; return 1
    fi
    cw_df_git -C "$repo" cat-file -e "$(cw_df_reference)^{commit}" &&
        cw_df_git -C "$repo" fsck --full --no-reflogs >/dev/null 2>&1 || {
        cw_log FAIL 'Objetos Git/referência inválidos'; return 1;
    }
    for id in terminal git vscode; do
        cw_df_entry "$id" || return 1
        file="$repo/$relative"
        cw_df_safe "$file" && [ -f "$file" ] && [ -s "$file" ] || {
            cw_log FAIL "Arquivo esperado ausente, vazio ou inseguro: $relative"; return 1;
        }
        # Hash bytes only: never invoke clean/smudge filters or external diff.
        [ "$(cw_df_git -C "$repo" hash-object --no-filters "$file")" = \
          "$(cw_df_git -C "$repo" rev-parse "HEAD:$relative")" ] || {
            cw_log REVIEW "Arquivo esperado difere do commit HEAD: $relative; preservar e revisar"; return 1;
        }
    done
    if [ -n "$(find "$repo/.git" -name '*.lock' -print)" ]; then
        cw_log REVIEW 'Lock Git ativo ou residual; revisar sem remover automaticamente'; return 1
    fi
    cw_log OK "Checkout independente validado: $repo"
}
cw_df_state_check() {
    local dir journal backup
    if ! cw_df_safe "$state"; then cw_log FAIL "Estado inseguro: $state"; return 1; fi
    case "$state/" in "$repo/"*|"$CW_ROOT/"*) cw_log FAIL 'Estado/backups dentro do checkout ou CLI'; return 1 ;; esac
    case "$repo/" in "$state/"*) cw_log FAIL 'Checkout dentro do estado/backups'; return 1 ;; esac
    if [ ! -e "$state" ]; then cw_log INFO "Estado/backups ainda não criados: $state"; return 0; fi
    [ -d "$state" ] && [ -r "$state" ] && [ -x "$state" ] || return 1
    local bad=0 mode
    mode=$(stat -c '%a' "$state" 2>/dev/null || stat -f '%Lp' "$state") || return 1
    case "$mode" in *00) ;; *) cw_log REVIEW "Estado/backups acessíveis a outros usuários: $state"; bad=1 ;; esac
    if [ -e "$state/lock" ] || [ -L "$state/lock" ]; then
        cw_log REVIEW "Lock ativo ou residual (não removido): $state/lock"; bad=1
    fi
    for dir in "$state"/operation.*; do
        [ -e "$dir" ] || [ -L "$dir" ] || continue
        journal="$dir/journal"
        if ! cw_df_safe "$journal" || [ ! -f "$journal" ] || [ ! -r "$journal" ]; then
            cw_log REVIEW "Operação sem journal legível/seguro: $dir"; bad=1; continue
        fi
        if [ "$(tail -n 1 "$journal")" != complete ]; then
            cw_log REVIEW "Journal incompleto; recuperação manual: $journal"; bad=1
        fi
        for backup in "$dir/original" "$dir/original-link"; do
            [ -e "$backup" ] || [ -L "$backup" ] || continue
            if [ "$backup" = "$dir/original-link" ] && [ -L "$backup" ]; then
                cw_log INFO "Backup de link preservado: $backup"
            elif [ ! -L "$backup" ] && [ -f "$backup" ] && [ -r "$backup" ]; then
                cw_log INFO "Backup legível: $backup"
            else cw_log REVIEW "Backup inesperado/ilegível: $backup"; bad=1; fi
        done
    done
    return "$bad"
}
cw_df_assist() (
    set -eu
    umask 077
    action=$1; shift
    dry=0
    if [ "$action" = init ] && [ "${1:-}" = --dry-run ]; then dry=1; shift; fi
    [ "$#" -eq 0 ] || { cw_log FAIL 'Uso: dotfiles init [--dry-run] | doctor'; exit 2; }
    df_home=$(CDPATH= cd -- "$HOME" && pwd -P) || exit 1
    repo=${CW_DOTFILES_REPO:-${XDG_DATA_HOME:-$df_home/.local/share}/config-workplace-dotfiles/repository}
    state=${XDG_STATE_HOME:-$df_home/.local/state}/config-workplace/dotfiles
    cw_df_manifest || { cw_log FAIL 'Manifesto da CLI inválido'; exit 1; }
    bad=0
    cw_platform || bad=1
    for dependency in git env find cmp cksum stat readlink tail head wc tr grep mkdir mktemp rmdir; do
        command -v "$dependency" >/dev/null 2>&1 || { cw_log FAIL "Dependência ausente: $dependency"; bad=1; }
    done
    if [ "$action" = doctor ]; then
        cw_df_permanent "$repo" || bad=1
        cw_df_permanent "$state" || bad=1
        if cw_df_safe "$repo" && [ -d "$repo" ]; then cw_df_checkout_valid || bad=1
        else cw_log REVIEW "Checkout permanente ausente/inseguro: $repo"; bad=1; fi
        for id in terminal git; do
            cw_df_entry "$id" || exit 1
            source_file="$repo/$relative"; destination=$(cw_df_destination "$id")
            if ! cw_df_safe "${destination%/*}" || ! cw_df_safe "$source_file"; then
                cw_log REVIEW "Ancestral inseguro: $destination"; bad=1; continue
            fi
            kind=$(cw_df_kind)
            cw_log "$kind" "$id: $destination -> $source_file"
            case "$kind" in correct) ;; *) bad=1 ;; esac
            if [ -L "$destination" ]; then
                link=$(readlink "$destination")
                cw_df_permanent "$link" || bad=1
            fi
        done
        cw_df_vscode || bad=1
        cw_df_state_check || bad=1
        cw_log INFO 'Diagnóstico somente leitura; nenhuma correção executada. Startup pessoal não é executado.'
        exit "$bad"
    fi
    [ "$bad" -eq 0 ] || exit 1
    cw_df_permanent "$repo" && cw_df_permanent "$state" || exit 1
    cw_df_state_check || exit 1
    if [ -e "$repo" ] || [ -L "$repo" ]; then
        cw_df_checkout_valid || exit 1
        cw_log SKIP 'Checkout existente reutilizado; sem clone, checkout, fetch ou pull.'
        exit 0
    fi
    cw_log PLAN "Clonar origem aprovada: $(cw_df_origin)"
    cw_log PLAN "Referência fixa: $(cw_df_reference); destino permanente: $repo"
    cw_log PLAN "Criar diretórios privados e journal em $state. Não aplicar links/includes nem executar scripts."
    [ "$dry" -eq 0 ] || exit 0
    cw_confirm || { cw_log SKIP 'Inicialização recusada'; exit 0; }
    cw_df_permanent "$repo" && cw_df_permanent "$state" && cw_df_state_check || exit 1
    [ ! -e "$repo" ] && [ ! -L "$repo" ] || { cw_log FAIL 'Destino surgiu após confirmação; preservado'; exit 1; }
    mkdir -p "$state" || exit 1
    mkdir "$state/lock" || exit 1
    transaction=
    cleanup_init() {
        result=$?
        trap - EXIT
        if [ "$result" -ne 0 ] && [ -n "$transaction" ]; then
            printf 'incomplete\n' >> "$transaction/journal" || :
            cw_log REVIEW "Inicialização interrompida; checkout e journal preservados: $transaction. Revisão manual, sem rollback."
        fi
        rmdir "$state/lock" || :
        exit "$result"
    }
    trap cleanup_init EXIT
    trap 'exit 130' INT
    trap 'exit 143' HUP TERM
    transaction=$(mktemp -d "$state/operation.XXXXXX") || exit 1
    printf 'action\tinit\nsource\t%s\ndestination\t%s\nreference\t%s\nprepared\n' \
        "$(cw_df_origin)" "$repo" "$(cw_df_reference)" > "$transaction/journal" || exit 1
    cw_df_permanent "$repo" || exit 1
    mkdir -p "${repo%/*}" || exit 1
    # Exclusive reservation refuses even an empty directory created concurrently.
    mkdir "$repo" || exit 1
    printf 'cloning\n' >> "$transaction/journal" || exit 1
    cw_df_git clone --no-checkout --no-local --no-hardlinks --template= \
        "$(cw_df_origin)" "$repo" || exit 1
    cw_df_git -C "$repo" checkout --detach "$(cw_df_reference)" || exit 1
    cw_df_checkout_valid || exit 1
    printf 'complete\n' >> "$transaction/journal" || exit 1
    cw_log DONE 'Checkout preparado. Revise dotfiles link --all --dry-run; vinculação exige confirmação separada.'
)

# Phase 6: only the explicitly approved origin/main; never infer an upstream.
cw_sync_git() {
    env -i PATH="$PATH" HOME="$df_home" GIT_CONFIG_GLOBAL=/dev/null \
        GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT="${sync_prompt:-0}" GIT_OPTIONAL_LOCKS=0 \
        GIT_NO_LAZY_FETCH=1 GIT_NO_REPLACE_OBJECTS=1 \
        git -c init.templateDir= -c protocol.allow=never -c protocol.https.allow=always \
        -c core.hooksPath=/dev/null -c core.fsmonitor=false \
        -c core.attributesFile=/dev/null -c core.pager=cat -c color.ui=false \
        -c credential.helper= -c http.followRedirects=false \
        -c commit.gpgSign=false -c tag.gpgSign=false -c gc.auto=0 \
        -c maintenance.auto=false -c submodule.recurse=false "$@"
}
cw_sync_path() {
    case "$1" in manifests/terminal/zshrc|manifests/git.config|manifests/vscode-settings.json) return 0 ;; esac
    cw_log REVIEW 'Arquivo fora da allowlist; nomes/conteúdo não exibidos. Revise localmente.'
    return 1
}
cw_sync_guard() {
    local key item flags
    cw_df_permanent "$repo" && cw_df_safe "$repo/.git" && [ -d "$repo/.git" ] || return 1
    [ -z "$(find "$repo/.git" ! -type d ! -type f -print)" ] || return 1
    for item in commondir objects/info/alternates objects/info/http-alternates shallow info/grafts info/attributes \
        MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-apply rebase-merge sequencer; do
        [ ! -e "$repo/.git/$item" ] || { cw_log REVIEW 'Metadados externos, atributos ou operação Git pendente'; return 1; }
    done
    [ -z "$(find "$repo/.git" -name '*.lock' -print)" ] || { cw_log REVIEW 'Lock Git ativo/residual'; return 1; }
    # Read config as data, WITHOUT following includes. Unknown keys fail closed.
    cw_df_git -C "$repo" config --local --no-includes --name-only --list > "$scratch/config-keys" || return 1
    while IFS= read -r key; do
        case "$key" in
            core.repositoryformatversion|core.filemode|core.bare|core.logallrefupdates|core.ignorecase|core.precomposeunicode|core.hookspath|\
            remote.origin.url|remote.origin.fetch|branch.main.remote|branch.main.merge|user.name|user.email) ;;
            *) cw_log REVIEW 'Configuração Git local não aprovada; revise sem executar includes, filtros ou helpers.'; return 1 ;;
        esac
    done < "$scratch/config-keys"
    [ "$(cw_sync_git -C "$repo" rev-parse --show-toplevel)" = "$repo" ] &&
    [ "$(cw_sync_git -C "$repo" config --local --get-all remote.origin.url)" = "$(cw_df_origin)" ] &&
    [ "$(cw_sync_git -C "$repo" symbolic-ref -q HEAD)" = refs/heads/main ] || {
        cw_log REVIEW 'Exige checkout independente com origem aprovada e branch main já selecionada manualmente.'; return 1;
    }
    [ "$(cw_sync_git -C "$repo" rev-parse --is-bare-repository)" = false ] || return 1
    cw_sync_git -C "$repo" cat-file -e "$(cw_df_reference)^{commit}" || return 1
    cw_sync_git -C "$repo" fsck --full --no-reflogs >/dev/null 2>&1 || return 1
    cw_sync_git -C "$repo" ls-files -v > "$scratch/index-flags" || return 1
    while IFS= read -r flags; do
        case "$flags" in 'H '*) ;; *) cw_log REVIEW 'Índice com conflitos, skip-worktree ou assume-unchanged'; return 1 ;; esac
    done < "$scratch/index-flags"
    cw_sync_git -C "$repo" diff --cached --quiet --no-ext-diff --no-textconv || {
        cw_log REVIEW 'Índice já contém alterações; preserve e revise o staging manualmente.'; return 1;
    }
    for item in .gitattributes manifests/.gitattributes manifests/terminal/.gitattributes; do
        [ ! -e "$repo/$item" ] && [ ! -L "$repo/$item" ] || { cw_log REVIEW 'Atributos Git exigem revisão manual'; return 1; }
    done
    for item in manifests/terminal/zshrc manifests/git.config manifests/vscode-settings.json; do
        cw_df_safe "$repo/$item" || return 1
        if [ -e "$repo/$item" ]; then
            [ -f "$repo/$item" ] || return 1
            [ "$(stat -c '%h' "$repo/$item" 2>/dev/null || stat -f '%l' "$repo/$item")" = 1 ] || {
                cw_log REVIEW 'Fonte com hardlinks; atualização pode afetar arquivos externos'; return 1;
            }
        fi
    done
}
# Scan before printing ANY content. This heuristic supplements human review.
cw_sync_scan() {
    local result=0
    [ "$(wc -c < "$1" | tr -d ' ')" -le 262144 ] || return 1
    # Refuse binary/control bytes (including terminal escapes) and non-ASCII data.
    LC_ALL=C tr -d '\11\12\15\40-\176' < "$1" > "$scratch/control" || return 1
    [ ! -s "$scratch/control" ] || return 1
    if LC_ALL=C grep -Ei 'PRIVATE KEY|(password|passwd|secret|token|credential|api[_-]?key|authorization)["[:space:]]*[=:]|bearer[[:space:]]|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]+|github_pat_|xox[baprs]-|sk-[A-Za-z0-9_-]{16}|https?://[^ /]+@|corporat|empresa|internal\.|corp\.|BEGIN (RSA|OPENSSH|EC|DSA)' "$1" >/dev/null; then
        return 1
    else result=$?; [ "$result" -eq 1 ]; fi
}
cw_sync_blob() {
    local tree=$1 path=$2 mode
    if cw_sync_git --git-dir="$scratch/git" cat-file -e "$tree:$path" 2>/dev/null; then
        mode=$(cw_sync_git --git-dir="$scratch/git" ls-tree "$tree" -- "$path") || return 1
        case "$mode" in '100644 blob '*|'100755 blob '*) ;; *) return 1 ;; esac
        cw_sync_git --git-dir="$scratch/git" cat-file blob "$tree:$path" > "$scratch/blob" || return 1
        cw_sync_scan "$scratch/blob" || return 1
    fi
}
cw_sync_history() {
    local range=$1 commit parent path parents
    cw_sync_git --git-dir="$scratch/git" rev-list "$range" > "$scratch/commits" || return 1
    while IFS= read -r commit; do
        parents=$(cw_sync_git --git-dir="$scratch/git" rev-list --parents -n 1 "$commit") || return 1
        # Reject merges: reviewing only first-parent hides intermediate disclosures.
        set -- $parents
        [ "$#" -eq 2 ] || { cw_log REVIEW 'Commit de merge/raiz exige revisão manual'; return 1; }
        parent=$2
        cw_sync_git --git-dir="$scratch/git" diff-tree --no-commit-id --no-renames -r --name-only -z "$parent" "$commit" > "$scratch/history-paths" || return 1
        while IFS= read -r -d '' path; do
            cw_sync_path "$path" && cw_sync_blob "$parent" "$path" && cw_sync_blob "$commit" "$path" || return 1
        done < "$scratch/history-paths"
        # Commit metadata can also disclose credentials; do not display subjects.
        cw_sync_git --git-dir="$scratch/git" cat-file commit "$commit" > "$scratch/commit" || return 1
        cw_sync_scan "$scratch/commit" || return 1
    done < "$scratch/commits"
}
cw_sync_snapshot() {
    local path
    cw_sync_git -C "$repo" rev-parse HEAD || return 1
    cksum "$repo/.git/index" "$repo/.git/config" || return 1
    cw_sync_git -C "$repo" status --porcelain=v1 -z --untracked-files=all > "$scratch/status" || return 1
    cksum < "$scratch/status"
    for path in manifests/terminal/zshrc manifests/git.config manifests/vscode-settings.json; do
        if [ -f "$repo/$path" ]; then cw_df_identity "$repo/$path"; cksum < "$repo/$path"
        else printf 'absent\n'; fi
    done
}
cw_sync_recheck() {
    cw_sync_guard && [ "$(cw_sync_snapshot)" = "$before_sync" ] || {
        cw_log REVIEW 'Checkout mudou depois do preview; operação interrompida, sem rollback.'; return 1;
    }
}
cw_dotfiles_sync() (
    set -eu
    umask 077
    mode=apply
    sync_prompt=0
    case "${1:-}" in --dry-run) mode=dry; shift ;; --status) mode=status; shift ;; esac
    [ "$#" -eq 0 ] || { cw_log FAIL 'Uso: workspace dotfiles sync [--dry-run | --status]'; exit 2; }
    df_home=$(CDPATH= cd -- "$HOME" && pwd -P)
    repo=${CW_DOTFILES_REPO:-${XDG_DATA_HOME:-$df_home/.local/share}/config-workplace-dotfiles/repository}
    state=${XDG_STATE_HOME:-$df_home/.local/state}/config-workplace/dotfiles
    cw_platform && cw_df_manifest && cw_df_permanent "$state" && cw_df_state_check || exit 1
    scratch=$(mktemp -d "${TMPDIR:-/tmp}/cw-sync.XXXXXX")
    transaction=; locked=0
    cleanup_sync() {
        result=$?
        trap - EXIT
        if [ -n "$transaction" ] && [ "$result" -ne 0 ]; then
            printf 'incomplete\n' >> "$transaction/journal" || :
            cw_log REVIEW "Falha; preservar checkout e revisar journal: $transaction/journal"
        fi
        [ "$locked" -eq 0 ] || rmdir "$state/lock" || :
        # Only our private disposable inspection store, never the checkout.
        rm -rf "$scratch"
        exit "$result"
    }
    trap cleanup_sync EXIT
    trap 'exit 130' INT
    trap 'exit 143' HUP TERM
    cw_sync_guard || exit 1
    head=$(cw_sync_git -C "$repo" rev-parse HEAD)
    before_sync=$(cw_sync_snapshot)
    cw_sync_git -C "$repo" diff --no-ext-diff --no-textconv --no-renames --name-only -z HEAD > "$scratch/paths"
    cw_sync_git -C "$repo" ls-files --others --exclude-standard -z >> "$scratch/paths"
    selected=(); count=0
    while IFS= read -r -d '' path; do
        cw_sync_path "$path" || exit 1
        if [ -f "$repo/$path" ]; then
            cw_sync_scan "$repo/$path" || { cw_log REVIEW 'Conteúdo suspeito/binário bloqueado antes do diff. Revise em área privada; não há bypass.'; exit 1; }
        fi
        selected[$count]=$path; count=$((count + 1))
    done < "$scratch/paths"
    # Bare object store only: no second working tree or dependency on initial clone.
    # Network reads and temporary objects are permitted even in preview; permanent
    # objects, refs, index and files remain unchanged until approval.
    cw_sync_git init --bare --quiet "$scratch/git"
    cp -R "$repo/.git/objects/." "$scratch/git/objects/"
    cw_log CHECK 'Consultar somente origem aprovada, refs/heads/main (sem credenciais/configuração pessoal).'
    if ! cw_sync_git --git-dir="$scratch/git" fetch --quiet --no-tags --no-recurse-submodules \
        "$(cw_df_origin)" refs/heads/main:refs/heads/review > "$scratch/network" 2>&1; then
        cw_log REVIEW 'Consulta remota falhou (rede, autenticação ou main ausente). Diagnóstico bruto não exibido; nada sincronizado.'; exit 1
    fi
    remote=$(cw_sync_git --git-dir="$scratch/git" rev-parse refs/heads/review)
    cw_sync_git --git-dir="$scratch/git" fsck --full --no-reflogs >/dev/null 2>&1 || exit 1
    ahead=$(cw_sync_git --git-dir="$scratch/git" rev-list --count "$remote..$head")
    behind=$(cw_sync_git --git-dir="$scratch/git" rev-list --count "$head..$remote")
    cw_log PLAN "origin/main: commits locais=$ahead; remotos=$behind; arquivos locais=$count"
    # Scan every intermediate blob, not merely the final diff.
    if ! cw_sync_history "$remote..$head" || ! cw_sync_history "$head..$remote"; then
        cw_log REVIEW 'Histórico fora da allowlist ou conteúdo suspeito. Diff suprimido; revisão privada obrigatória.'; exit 1
    fi
    if [ "$count" -gt 0 ]; then
        for path in "${selected[@]}"; do
            cw_sync_blob "$head" "$path" || { cw_log REVIEW 'Conteúdo anterior suspeito; diff bloqueado'; exit 1; }
        done
    fi
    if [ "$ahead" -gt 0 ] || [ "$behind" -gt 0 ]; then
        cw_sync_git --git-dir="$scratch/git" log --format='%h' "$head...$remote"
        if [ "$behind" -eq 0 ]; then diff_from=$remote; diff_to=$head
        else diff_from=$head; diff_to=$remote; fi
        cw_sync_git --git-dir="$scratch/git" diff --no-ext-diff --no-textconv --no-renames --stat "$diff_from" "$diff_to"
        cw_sync_git --git-dir="$scratch/git" diff --no-ext-diff --no-textconv --no-renames "$diff_from" "$diff_to"
    fi
    if [ "$count" -gt 0 ]; then
        cw_sync_git -C "$repo" diff --no-ext-diff --no-textconv --no-renames HEAD -- "${selected[@]}"
        for path in "${selected[@]}"; do
            if ! cw_sync_git -C "$repo" cat-file -e "HEAD:$path" 2>/dev/null && [ -f "$repo/$path" ]; then
                printf '\nAdicionado: %s\n' "$path"; cat "$repo/$path"
            fi
        done
    fi
    if [ "$behind" -gt 0 ] && { [ "$ahead" -gt 0 ] || [ "$count" -gt 0 ]; }; then
        cw_log REVIEW 'Alterações locais e remotas/divergência. Preserve ambos os lados e resolva manualmente em área separada; nenhum merge realizado.'; exit 1
    fi
    if [ "$count" -eq 0 ] && [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
        cw_log SKIP 'Sem alterações; nenhum commit.'; exit 0
    fi
    [ "$mode" = apply ] || { cw_log PLAN 'Somente preview: checkout, índice, refs e HOME preservados.'; exit 0; }
    if [ "$behind" -gt 0 ]; then
        cw_log PLAN 'Atualizar checkout por fast-forward exato. Fontes já vinculadas afetam terminal/Git. HOME não será escrito. Backup e journal serão preservados.'
    elif [ "$count" -gt 0 ]; then
        cw_log PLAN 'Registrar TODOS os arquivos permitidos exibidos em commit local. Confirme também que não contêm informações corporativas/sensíveis. Push terá confirmação separada.'
        # Require explicitly prepared repository-local identity; never configure it.
        cw_sync_git -C "$repo" config --local --get user.name >/dev/null &&
        cw_sync_git -C "$repo" config --local --get user.email >/dev/null || {
            cw_log REVIEW 'Configure manualmente user.name/user.email locais após revisão; identidade global não é importada.'; exit 1;
        }
        cw_sync_git -C "$repo" config --local --get user.name > "$scratch/identity"
        cw_sync_git -C "$repo" config --local --get user.email >> "$scratch/identity"
        cw_sync_scan "$scratch/identity" || { cw_log REVIEW 'Identidade local suspeita; revise em privado'; exit 1; }
    else cw_log PLAN 'Publicar commits locais revisados em origin/main; sem force push.'; fi
    cw_confirm || { cw_log SKIP 'Operação recusada; checkout preservado'; exit 0; }
    cw_sync_recheck && cw_df_state_check || exit 1
    mkdir -p "$state"
    mkdir "$state/lock" || exit 1
    locked=1
    cw_sync_recheck || exit 1
    transaction=$(mktemp -d "$state/operation.XXXXXX")
    printf 'action\tsync\ndestination\t%s\nbefore\t%s\nremote\t%s\nbranch\tmain\nprepared\n' "$repo" "$head" "$remote" > "$transaction/journal"
    cp -p "$repo/.git/index" "$transaction/index.before"
    mkdir "$transaction/files"
    for path in manifests/terminal/zshrc manifests/git.config manifests/vscode-settings.json; do
        if [ -f "$repo/$path" ]; then
            mkdir -p "$transaction/files/${path%/*}"
            cp -p "$repo/$path" "$transaction/files/$path"
        fi
    done
    if [ "$behind" -gt 0 ]; then
        # Import the inspected immutable objects; update exactly the reviewed OID.
        cw_sync_git -c protocol.file.allow=always -C "$repo" fetch --quiet --no-tags --no-write-fetch-head --no-recurse-submodules "$scratch/git" refs/heads/review > "$scratch/import" 2>&1 || exit 1
        cw_sync_recheck || exit 1
        printf 'updating\n' >> "$transaction/journal"
        cw_sync_git -C "$repo" merge --ff-only --no-edit "$remote" > "$scratch/update" 2>&1 || exit 1
        [ "$(cw_sync_git -C "$repo" rev-parse HEAD)" = "$remote" ] || exit 1
        printf 'complete\n' >> "$transaction/journal"
        cw_log DONE 'Checkout atualizado; configurações pessoais preservadas.'; exit 0
    fi
    if [ "$count" -gt 0 ]; then
        cw_sync_recheck || exit 1
        printf 'staging\n' >> "$transaction/journal"
        cw_sync_git -C "$repo" add -- "${selected[@]}" > "$scratch/add" 2>&1 || exit 1
        # Verify actual staged blobs against private copies of the approved bytes.
        cw_sync_git -C "$repo" diff --cached --no-renames --name-only -z > "$scratch/staged"
        staged_count=0
        while IFS= read -r -d '' path; do
            found=0
            for selected_path in "${selected[@]}"; do [ "$selected_path" != "$path" ] || found=1; done
            [ "$found" -eq 1 ] || exit 1
            if [ -f "$transaction/files/$path" ]; then
                [ "$(cw_sync_git -C "$repo" rev-parse ":$path")" = \
                  "$(cw_sync_git -C "$repo" hash-object --no-filters "$transaction/files/$path")" ] || exit 1
            else
                if cw_sync_git -C "$repo" cat-file -e ":$path" 2>/dev/null; then exit 1; fi
            fi
            staged_count=$((staged_count + 1))
        done < "$scratch/staged"
        [ "$staged_count" -eq "$count" ] || exit 1
        approved_tree=$(cw_sync_git -C "$repo" write-tree)
        printf 'committing\n' >> "$transaction/journal"
        cw_sync_git -C "$repo" commit -m 'chore(dotfiles): sync reviewed portable preferences' > "$scratch/commit-output" 2>&1 || exit 1
        [ "$(cw_sync_git -C "$repo" rev-parse HEAD^)" = "$head" ] &&
        [ "$(cw_sync_git -C "$repo" rev-parse 'HEAD^{tree}')" = "$approved_tree" ] || exit 1
        head=$(cw_sync_git -C "$repo" rev-parse HEAD)
        printf 'committed\t%s\n' "$head" >> "$transaction/journal"
        cw_log DONE "Commit local criado: $head"
        before_sync=$(cw_sync_snapshot)
        cw_log PLAN 'Publicar esse commit e os commits locais revisados na origem aprovada, branch main?'
        if ! cw_confirm; then
            printf 'push-declined\ncomplete\n' >> "$transaction/journal"
            cw_log SKIP 'Push recusado; commit local preservado para próxima execução.'; exit 0
        fi
    fi
    cw_sync_recheck || exit 1
    printf 'pushing\n' >> "$transaction/journal"
    cw_log INFO 'Git poderá pedir usuário/token no terminal. Nenhum helper é executado ou credencial configurada/armazenada.'
    sync_prompt=1
    # Exact object/refspec, no upstream changes, no force, no pushurl or URL rewrite.
    if ! cw_sync_git -C "$repo" push --porcelain "$(cw_df_origin)" "$head:refs/heads/main" > "$scratch/push" 2>&1; then
        cw_log REVIEW 'Push falhou (rede/autenticação ou remoto avançou). Commit local preservado; não repetir sem revisar estado/journal.'; exit 1
    fi
    printf 'complete\n' >> "$transaction/journal"
    cw_log DONE 'Publicação concluída em origin/main.'
)
