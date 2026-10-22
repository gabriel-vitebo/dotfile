# Bash 3.2; deliberately one approved target, no discovery or executable manifest.
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
cw_df_kind() {
    if [ -L "$destination" ]; then
        if [ "$(readlink "$destination")" = "$source_file" ]; then
            if [ -f "$source_file" ]; then printf correct; else printf broken-managed; fi
        elif [ -e "$destination" ]; then printf foreign-link; else printf broken-foreign; fi
    elif [ -f "$destination" ]; then
        if cmp -s "$destination" "$source_file"; then printf identical; else printf divergent; fi
    elif [ -e "$destination" ]; then printf conflict
    else printf absent; fi
}
cw_dotfiles() (
    set -eu
    umask 077
    action=${1:-help}; [ "$#" -eq 0 ] || shift
    dry=0
    case "$action" in
        help|--help) printf '%s\n' 'Uso: workspace dotfiles {link|status|unlink} [--dry-run]' 'Fonte: CW_DOTFILES_REPO ou ~/.local/share/config-workplace-dotfiles/repository' 'Alvo único: terminal-fragment; .zshrc pessoal não é alterado.'; exit 0 ;;
        link|status|unlink) ;;
        *) cw_log FAIL 'Subcomando dotfiles inválido'; exit 2 ;;
    esac
    for arg in "$@"; do
        case "$arg" in --dry-run) dry=1 ;; *) cw_log FAIL "Opção inválida: $arg"; exit 2 ;; esac
    done
    home=$(CDPATH= cd -- "$HOME" && pwd -P)
    repo=${CW_DOTFILES_REPO:-${XDG_DATA_HOME:-$home/.local/share}/config-workplace-dotfiles/repository}
    cw_df_safe "$repo" || { cw_log FAIL 'Raiz do repositório insegura'; exit 1; }
    [ -d "$repo" ] || { cw_log REVIEW "Prepare um checkout permanente e configure CW_DOTFILES_REPO: $repo"; exit 1; }
    repo=$(CDPATH= cd -- "$repo" && pwd -P)
    case "$repo/" in "$home/.local/share/config-workplace/"*) cw_log FAIL 'Fonte não pode ficar na instalação substituível da CLI'; exit 1 ;; esac
    source_file="$repo/manifests/terminal/zshrc"
    destination="$home/.config/config-workplace-terminal/zshrc"
    state=${XDG_STATE_HOME:-$home/.local/state}/config-workplace/dotfiles
    cw_df_safe "$source_file" && cw_df_safe "${destination%/*}" && cw_df_safe "$state" || { cw_log FAIL 'Caminho ou ancestral simbólico não permitido'; exit 1; }
    case "$state/" in "$repo/"*|"$CW_ROOT/"*) cw_log FAIL 'Estado/backups devem ficar fora do repositório'; exit 1 ;; esac
    kind=$(cw_df_kind)
    cw_log "$kind" "terminal-fragment: $destination -> $source_file"
    if [ -d "$state/lock" ]; then cw_log REVIEW "Operação pendente/lock residual: $state/lock; revise journals antes de remover o lock vazio"; exit 1; fi
    if [ "$action" = status ]; then [ "$kind" = correct ]; exit $?; fi
    if [ "$action" = link ]; then
        [ -f "$source_file" ] || { cw_log FAIL 'Fonte ausente'; exit 1; }
        case "$kind" in
            correct) exit 0 ;;
            absent|identical) ;;
            *) cw_log REVIEW 'Conflito preservado. Revise/mescle manualmente em área local privada; nunca importe secrets. Links de terceiros não são substituídos.'; exit 1 ;;
        esac
        source_sum=$(cksum < "$source_file")
        cw_log REVIEW 'Criar link do fragmento aprovado. Startup, tema e plugins pessoais não serão editados; ativação deve ser revisada manualmente.'
    else
        case "$kind" in correct|broken-managed) ;; absent) exit 0 ;; *) cw_log REVIEW 'Não é link gerenciado; preservado'; exit 1 ;; esac
        cw_log REVIEW 'Remover somente este link; conteúdo da fonte e backups serão preservados. O fragmento deixará de ser carregado.'
    fi
    [ "$dry" -eq 0 ] || exit 0
    cw_confirm || { cw_log SKIP 'Operação recusada'; exit 0; }
    cw_df_safe "${destination%/*}" && cw_df_safe "$state" && cw_df_safe "$source_file" || exit 1
    [ "$(cw_df_kind)" = "$kind" ] || { cw_log FAIL 'Destino mudou durante confirmação'; exit 1; }
    if [ "$action" = link ]; then [ "$(cksum < "$source_file")" = "$source_sum" ] || exit 1; fi
    mkdir -p "$state" || exit 1
    mkdir "$state/lock" 2>/dev/null || exit 1
    transaction=
    cleanup() {
        result=$?
        trap - EXIT
        if [ -n "$transaction" ] && [ "$result" -ne 0 ]; then
            printf 'incomplete\n' >> "$transaction/journal"
            cw_log REVIEW "Falha: artefatos preservados em $transaction. Recuperação manual; nenhuma restauração destrutiva automática."
        fi
        rmdir "$state/lock" || :
        exit "$result"
    }
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' HUP TERM
    [ "$(cw_df_kind)" = "$kind" ] || exit 1
    transaction=$(mktemp -d "$state/operation.XXXXXX") || exit 1
    printf 'action\t%s\nsource\t%s\ndestination\t%s\nbefore\t%s\n' "$action" "$source_file" "$destination" "$kind" > "$transaction/journal"
    if [ "$kind" = identical ]; then
        cp -p "$destination" "$transaction/original" || exit 1
        cmp -s "$destination" "$transaction/original" || exit 1
        cw_log BACKUP "$transaction/original"
    elif [ "$action" = unlink ]; then
        cp -P "$destination" "$transaction/original-link" || exit 1
    fi
    printf 'prepared\n' >> "$transaction/journal"
    cw_df_safe "${destination%/*}" && cw_df_safe "$source_file" || exit 1
    [ "$(cw_df_kind)" = "$kind" ] || exit 1
    if [ "$action" = link ]; then
        [ "$(cksum < "$source_file")" = "$source_sum" ] || exit 1
        mkdir -p "${destination%/*}" || exit 1
        if [ "$kind" = identical ]; then
            cmp -s "$destination" "$transaction/original" || exit 1
            # Original preserved with permissions before removing the approved copy.
            rm "$destination" || exit 1
        fi
        # ln without force refuses anything created concurrently at the final path.
        ln -s "$source_file" "$destination" || exit 1
    else
        [ -L "$destination" ] && [ "$(readlink "$destination")" = "$source_file" ] || exit 1
        rm "$destination" || exit 1
    fi
    printf 'complete\n' >> "$transaction/journal"
    cw_log DONE "$action: $transaction"
)
