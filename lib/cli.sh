# Shared CLI interface; compatible with Bash 3.2.
cw_main() {
    if [ "${1:-}" = java ]; then
        shift
        . "$CW_ROOT/lib/setup.sh"
        . "$CW_ROOT/modules/java.sh"
        cw_java "$@"
        return $?
    fi
    if [ "${1:-}" = terminal ]; then
        shift
        . "$CW_ROOT/lib/setup.sh"
        . "$CW_ROOT/modules/terminal.sh"
        cw_terminal "$@"
        return $?
    fi
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
                '     config-workplace terminal [--dry-run] [--change-shell]' \
                '     config-workplace java [--dry-run]' \
                'CLI pessoal para ambientes de desenvolvimento.' ;;
        --version) printf '%s\n' 'config-workplace 0.2.2' ;;
        list) printf '%s\n' 'Disponível: terminal (Zsh, Oh My Zsh, robbyrussell, git e Vim)' \
             'Disponível: initial dev (Git, gh, NVM, Node LTS, npm, pnpm, VS Code, extensões e utilitários)' \
            'Disponível: java (SDKMAN! opcional, JDK LTS, Maven, Gradle e extensões Java)' \
            'Módulos planejados (ainda indisponíveis): docker, env' ;;
        *) printf 'Erro: comando não implementado: %s\n' "$1" >&2; return 2 ;;
    esac
}
