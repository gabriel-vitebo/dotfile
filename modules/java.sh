. "$CW_ROOT/lib/dev-safety.sh"
. "$CW_ROOT/lib/dev-tools.sh"
. "$CW_ROOT/lib/java-detect.sh"
. "$CW_ROOT/lib/java-versions.sh"
. "$CW_ROOT/lib/java-sdkman.sh"
. "$CW_ROOT/lib/java-vscode.sh"

cw_java() (
    dry=0
    for arg in "$@"; do
        case "$arg" in --dry-run) dry=1 ;; *) cw_log FAIL "Opção inválida: $arg"; exit 2 ;; esac
    done
    cw_platform || exit 1
    cw_log CHECK 'config-workplace — Java'
    actions=(); versions=(); blocked=0; home_ok=1
    java_candidate=; java_target_major=; sdk_installer=
    jdk_state=0; cw_java_probe || jdk_state=$?
    case "$jdk_state" in
        0)
            cw_log SKIP "Java JDK: $java_version; $(cw_java_origin "$java_bin"); versões antigas funcionais também são preservadas."
            java_target_major=$java_major
            if ! cw_java_home_check; then
                cw_log REVIEW 'JAVA_HOME inválido ou divergente do JDK detectado; preserve/revise a seleção antes de instalar ferramentas.'
                home_ok=0
            fi ;;
        1|3)
            if [ "$jdk_state" -eq 3 ]; then cw_log REVIEW 'Runtime sem compilador funcional: JDK incompleto; instalação de um JDK exige decisão específica.'; fi
            if [ -n "${JAVA_HOME:-}" ]; then
                cw_log REVIEW 'JAVA_HOME existente preservado; revise/remova o conflito na sessão antes de instalar JDK.'; home_ok=0; blocked=1
            elif cw_java_lts; then
                actions[${#actions[@]}]=java; versions[${#versions[@]}]=$java_candidate
                cw_log INSTALL "Java JDK Temurin $java_candidate (LTS $java_target_major, catálogo da plataforma); confirmação específica antes de criar seleção SDKMAN!."
            else cw_log REVIEW 'Não foi possível resolver JDK LTS Temurin com segurança; nenhuma versão presumida.'; blocked=1; fi ;;
        *) cw_log REVIEW 'Java/Javac existente com falha ou versões divergentes; reparo manual, sem substituir.'; blocked=1 ;;
    esac
    # Keep the detected JDK for build-tool probes without changing the caller or startup.
    if [ "$jdk_state" -eq 0 ] && [ "$home_ok" -eq 1 ]; then
        export PATH="${java_bin%/*}:$PATH"
    fi
    for tool in maven gradle; do
        state=0; cw_java_tool_probe "$tool" || state=$?
        case "$state" in
            0) cw_log SKIP "$tool: ${cw_version%%$'\n'*}; $(cw_java_origin "$cw_tool_path")" ;;
            1)
                if [ "$home_ok" -eq 1 ] && [ -n "$java_target_major" ] && version=$(cw_java_build_version "$tool" "$java_target_major"); then
                    actions[${#actions[@]}]=$tool; versions[${#versions[@]}]=$version
                    cw_log INSTALL "$tool $version compatível com Java $java_target_major via SDKMAN! (aprovação individual)."
                else cw_log REVIEW "$tool ausente: versão estável/compatibilidade não resolvida; revise o JDK ou instale manualmente uma versão compatível, depois reexecute."; blocked=1; fi ;;
            *) cw_log REVIEW "$tool existe mas falhou; instalação/configurações preservadas."; blocked=1 ;;
        esac
    done
    for file in "$HOME/.m2/settings.xml" "$HOME/.gradle/gradle.properties"; do
        [ ! -e "$file" ] || cw_log SKIP "Configuração pessoal preservada: $file (conteúdo não lido)"
    done
    sdk_state=0; cw_java_sdk_probe || sdk_state=$?
    if [ "$sdk_state" -eq 0 ]; then
        cw_log SKIP "SDKMAN! $sdk_version encontrado; preservado. Execução validada somente se houver instalação aprovada."
    elif [ "${#actions[@]}" -eq 0 ] && [ "$sdk_state" -eq 1 ]; then cw_log SKIP 'SDKMAN! ausente e desnecessário para as ações disponíveis.'
    elif [ "$sdk_state" -eq 2 ]; then cw_log REVIEW 'SDKMAN! existente incompleto/não identificável; preservar e reparar manualmente.'; blocked=1
    else
        cw_java_sdk_prepare || { cw_log REVIEW 'SDKMAN!: preparação não resolvida; nenhuma instalação autorizada.'; blocked=1; }
    fi
    if [ "${#actions[@]}" -gt 0 ] && [ "$sdk_state" -eq 0 ]; then
        cw_java_sdk_shell || blocked=1
        cw_safe_destination "$sdk_dir" || blocked=1
        if [ "${SDKMAN_CANDIDATES_DIR:-$sdk_dir/candidates}" != "$sdk_dir/candidates" ]; then
            cw_log REVIEW 'SDKMAN_CANDIDATES_DIR personalizado: instalação adiada para revisão manual.'; blocked=1
        fi
    fi
    for tool in ${actions[@]+"${actions[@]}"}; do
        if [ -e "$sdk_dir/candidates/$tool/current" ] || [ -L "$sdk_dir/candidates/$tool/current" ]; then
            cw_log REVIEW "$tool tem seleção SDKMAN! existente; nenhuma alteração de default será realizada."; blocked=1
        fi
    done
    cw_java_editor_plan || exit 1
    cw_log PLAN 'Não editar JAVA_HOME, shell, settings, credenciais ou wrappers de projetos. SDKMAN!/ferramentas ficam em diretório permanente.'
    if [ "$dry" -eq 1 ]; then cw_log OK 'Dry-run: nenhuma alteração executada.'; exit "$blocked"; fi
    [ "$blocked" -eq 0 ] || { cw_log REVIEW 'Resolva as pendências e reexecute; plano bloqueado antes de qualquer alteração.'; exit 1; }
    [ "${#actions[@]}" -gt 0 ] || [ "${#java_extensions[@]}" -gt 0 ] || exit 0
    cw_confirm || { cw_log SKIP 'Operação cancelada; nenhuma alteração.'; exit 0; }
    if [ "${#actions[@]}" -gt 0 ] && [ "$sdk_state" -eq 1 ]; then
        cw_log PLAN "Autorizar explicitamente SDKMAN! $sdk_new_version em $sdk_dir?"
        cw_confirm || { cw_log SKIP 'SDKMAN! recusado; nenhuma instalação.'; exit 0; }
        cw_java_sdk_install || { cw_log FAIL 'SDKMAN!: instalação parcial pode permanecer; revise antes de reexecutar.'; exit 1; }
    fi
    index=0
    for tool in ${actions[@]+"${actions[@]}"}; do
        result=0; cw_java_install_candidate "$tool" "${versions[$index]}" || result=$?
        case "$result" in
            0) ;;
            3) cw_log SKIP "$tool recusado; instalações dependentes canceladas."; exit 0 ;;
            *) cw_log FAIL "$tool: falha parcial; instalações concluídas preservadas. Revise e reexecute."; exit 1 ;;
        esac
        index=$((index + 1))
    done
    cw_java_editor_apply || { cw_log FAIL 'Extensão Java: falha; demais instalações preservadas.'; exit 1; }
    if [ "${#actions[@]}" -gt 0 ]; then
        cw_log MANUAL 'Para novas sessões, revise e acrescente ao arquivo de inicialização do seu shell:'
        printf 'export SDKMAN_DIR=%q\n[ ! -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] || . "$SDKMAN_DIR/bin/sdkman-init.sh"\n' "$sdk_dir"
        cw_log MANUAL 'Carregar SDKMAN! ativa suas seleções current e pode definir JAVA_HOME. Nenhum arquivo de shell foi editado; escolha essa ativação explicitamente.'
    fi
    cw_log OK 'Java: execução concluída; consulte SKIP/REVIEW e instruções de ativação.'
)
