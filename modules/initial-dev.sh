. "$CW_ROOT/lib/dev-safety.sh"
. "$CW_ROOT/lib/dev-tools.sh"
. "$CW_ROOT/lib/vscode.sh"
. "$CW_ROOT/platforms/dev-install.sh"

# All detection finishes before confirmation or the first mutation.
cw_initial_dev() (
    dry=0
    approve_node=0
    for arg in "$@"; do
        case "$arg" in --dry-run) dry=1 ;; --approve-node-change) approve_node=1 ;; *) cw_log FAIL "Opção inválida: $arg"; return 2 ;; esac
    done
    cw_platform || return 1
    actions=()
    blocked=0
    for tool in git gh; do
        cw_log CHECK "$tool"
        state=0; cw_probe "$tool" || state=$?
        case "$state" in
            0) cw_log SKIP "$tool: $cw_version" ;;
            1) actions[${#actions[@]}]="$tool" ;;
            *) cw_log MANUAL "$tool existe mas não funciona; reparar explicitamente."; blocked=1 ;;
        esac
    done
    cw_log CHECK NVM
    state=0; cw_load_nvm || state=$?
    case "$state" in
        0) cw_log SKIP "NVM $(nvm --version)" ;;
        1) actions[${#actions[@]}]=nvm ;;
        *) cw_log MANUAL 'Instalação NVM existente não funcional; preservada.'; blocked=1 ;;
    esac
    cw_log CHECK Node.js
    state=0; cw_probe node || state=$?
    case "$state" in
        0)
            node_version=$cw_version
            case "$(command -v node)" in "${NVM_DIR:-$HOME/.nvm}"/versions/node/*) ;; *) cw_log INFO 'Node existente fora do NVM; não será migrado automaticamente.' ;; esac
            major=${node_version#v}; major=${major%%.*}
            latest=$(cw_lts_major) || latest=
            case "$latest" in ''|*[!0-9]*)
                    cw_log MANUAL 'Não foi possível verificar a política LTS; Node preservado.'
                    if command -v curl >/dev/null 2>&1; then blocked=1
                    else cw_log REVIEW 'Verificação LTS pendente; instale curl pelo plano e reexecute.'; fi ;;
                *) if [ "$major" = "$latest" ] && [ -n "$(node -p 'process.release.lts || ""' 2>/dev/null)" ]; then
                       cw_log SKIP "Node $node_version compatível com a major LTS atual ($latest)."
                   elif [ "$approve_node" -eq 1 ]; then actions[${#actions[@]}]=node
                   else cw_log MANUAL "Node $node_version diverge da major LTS atual ($latest). Para autorizar outra versão via NVM, repita com --approve-node-change e confirme o plano."; blocked=1; fi ;;
            esac ;;
        1) actions[${#actions[@]}]=node ;;
        *) cw_log MANUAL 'Node existente não funciona; reparo explícito necessário.'; blocked=1 ;;
    esac
    # Resolve an existing NVM LTS while planning, without activating or downloading.
    reuse_node=
    for tool in ${actions[@]+"${actions[@]}"}; do
        if [ "$tool" = node ] && command -v nvm >/dev/null 2>&1; then
            candidate=$(nvm version 'lts/*') || candidate=N/A
            if [ "$candidate" != N/A ] && [ -n "$candidate" ]; then
                latest=$(cw_lts_major) || latest=
                candidate_major=${candidate#v}; candidate_major=${candidate_major%%.*}
                if [ -n "$latest" ] && [ "$candidate_major" = "$latest" ]; then
                    reuse_node=$candidate
                else
                    cw_log MANUAL "NVM contém LTS $candidate fora da política atual ou não verificável; preservada. Revise antes de instalar outra versão."
                    blocked=1
                fi
            fi
        fi
    done
    cw_log CHECK npm
    npm_state=0; cw_probe npm || npm_state=$?
    if [ "$npm_state" -eq 0 ]; then cw_log SKIP "npm $cw_version"
    elif [ "$state" -ne 1 ]; then cw_log MANUAL 'npm ausente ou inválido no Node existente; não será instalado separadamente.'; blocked=1; fi
    for tool in ${actions[@]+"${actions[@]}"}; do
        cw_log PLAN "Instalar $tool"
        [ "$tool" != node ] || cw_log PLAN "Node LTS via NVM; configurar alias default lts/* (preserva versões anteriores)."
        case "$tool" in
            git|gh) if [ "$cw_os" = macos ]; then
                if ! cw_probe brew; then cw_log MANUAL 'Prepare Homebrew manualmente: https://brew.sh'; blocked=1; fi
            elif ! command -v apt-get >/dev/null; then blocked=1; fi ;;
        esac
    done
    if [ "${#actions[@]}" -gt 0 ] || command -v node >/dev/null; then
        if ! command -v curl >/dev/null; then cw_log PLAN 'curl será instalado antes dos downloads; compatibilidade remota poderá exigir nova execução.'; fi
    fi
    for tool in ${actions[@]+"${actions[@]}"}; do
        if [ "$tool" = node ] && [ -z "$reuse_node" ] && [ -f "${NVM_DIR:-$HOME/.nvm}/default-packages" ] && grep -Eq '^[[:space:]]*[^#[:space:]]' "${NVM_DIR:-$HOME/.nvm}/default-packages"; then
            cw_log MANUAL 'NVM default-packages solicita pacotes globais, fora do escopo. Revise esse arquivo antes de instalar Node.'
            blocked=1
        fi
    done
    [ -z "$reuse_node" ] || cw_log PLAN "Reutilizar Node $reuse_node disponível no NVM, sem instalar; configurar alias default."
    desired_default=
    if command -v nvm >/dev/null 2>&1 && [ -n "${NVM_DIR:-}" ]; then
        candidate=$(nvm version 'lts/*' 2>/dev/null) || candidate=N/A
        candidate_major=${candidate#v}; candidate_major=${candidate_major%%.*}
        if [ -n "${latest:-}" ] && [ "$candidate_major" = "$latest" ] &&
           [ "$(nvm version default 2>/dev/null)" != "$candidate" ]; then
            desired_default=$candidate
            cw_log PLAN "Configurar alias NVM default = $candidate; preservar seleção ativa."
            actions[${#actions[@]}]=nvm-default
        fi
    fi
    cw_dev_plan
    cw_nvm_shell_plan
    [ "$nvm_startup_review" -eq 0 ] || review_pending=1
    ordered=()
    for tool in ${actions[@]+"${actions[@]}"}; do
        case "$tool" in dev:curl|dev:ca-certificates) ordered[${#ordered[@]}]="$tool" ;; esac
    done
    for tool in ${actions[@]+"${actions[@]}"}; do
        case "$tool" in dev:curl|dev:ca-certificates) ;; *) ordered[${#ordered[@]}]="$tool" ;; esac
    done
    actions=( ${ordered[@]+"${ordered[@]}"} )
    [ "$blocked" -eq 0 ] || return 1
    [ "$dry" -eq 0 ] || { cw_log INFO 'Dry-run: nenhuma alteração executada.'; return 0; }
    [ "${#actions[@]}" -gt 0 ] || {
        cw_nvm_shell_apply || return 1
        if [ "${review_pending:-0}" -eq 1 ]; then cw_log REVIEW 'Nenhuma alteração automática; resolva as pendências informadas.'
        else cw_log OK 'Ambiente já configurado.'; fi
        return 0
    }
    [ "$cw_os" != ubuntu ] || cw_log INFO 'APT pode solicitar sudo; gh pode configurar o repositório oficial.'
    cw_confirm || { cw_log SKIP 'Operação cancelada; nenhuma alteração.'; return 0; }
    for tool in ${actions[@]+"${actions[@]}"}; do
        cw_log INSTALL "$tool"
        case "$tool" in
            dev:*) cw_install_tool "${tool#dev:}" || { cw_log FAIL "$tool"; return 1; } ;;
            vscode) cw_install_vscode || { cw_log FAIL "VS Code"; return 1; } ;;
            code-cli) cw_code_launcher || return 1 ;;
            editor) cw_editor_apply || return 1 ;;
            git|gh) cw_package "$tool" || { cw_log FAIL "$tool"; return 1; } ;;
            nvm) cw_install_nvm && cw_load_nvm || { cw_log FAIL NVM; return 1; } ;;
            nvm-default) nvm alias default "$desired_default" || return 1 ;;
            node)
                cw_load_nvm || return 1
                if [ -n "$reuse_node" ]; then
                    nvm use "$reuse_node" || return 1
                    cw_log SKIP "Node $reuse_node reutilizado"
                else
                    # If Node appeared after planning, preserve it and request a new plan.
                    if command -v node >/dev/null 2>&1 && [ "$approve_node" -ne 1 ]; then
                        cw_log MANUAL 'Node detectado após o plano; reexecute para verificar compatibilidade.'
                        return 1
                    fi
                    nvm install --lts || { cw_log FAIL Node.js; return 1; }
                fi
                nvm alias default 'lts/*' || return 1
                cw_log CONFIGURED 'Alias NVM default = lts/*' 
                cw_probe node && cw_probe npm || { cw_log FAIL 'Verificação Node/npm'; return 1; } ;;
        esac
        cw_log OK "$tool: etapa encerrada (consulte SKIP/REVIEW para pendências)"
    done
    cw_nvm_shell_apply || return 1
    gh auth status >/dev/null 2>&1 || cw_log MANUAL 'Autenticação opcional pendente: execute gh auth login quando desejar.'
    cw_log OK 'Etapas autorizadas encerradas; consulte REVIEW/MANUAL para eventuais pendências.'
)
