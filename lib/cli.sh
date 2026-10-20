# Shared CLI interface; compatible with Bash 3.2.
cw_main() {
    if [ "${1:-}" = initial ] && [ "${2:-}" = dev ]; then
        shift 2
        . "$CW_ROOT/lib/setup.sh"
        . "$CW_ROOT/modules/initial-dev.sh"
        cw_initial_dev "$@"
        return $?
    fi
    [ "$#" -le 1 ] || { printf '%s\n' 'Erro: argumentos excedentes. Use --help.' >&2; return 2; }
    case "${1:---help}" in
        --help|help)
            printf '%s\n' 'Uso: config-workplace [--help | --version | list]' \
                '     config-workplace initial dev [--dry-run] [--approve-node-change]' \
                'CLI pessoal para ambientes de desenvolvimento.' ;;
        --version) printf '%s\n' 'config-workplace 0.2.1' ;;
        list) printf '%s\n' 'Disponível: initial dev (Git, gh, NVM, Node LTS, npm)' \
            'Módulos planejados (ainda indisponíveis): java, docker, terminal, env' ;;
        *) printf 'Erro: comando não implementado: %s\n' "$1" >&2; return 2 ;;
    esac
}
