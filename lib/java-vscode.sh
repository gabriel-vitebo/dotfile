cw_java_editor_plan() {
    local extension list
    java_extensions=()
    cw_log SKIP 'VS Code Java settings: configurações existentes preservadas; nenhum perfil aprovado para importar.'
    if ! cw_vscode_probe; then
        cw_log REVIEW 'VS Code ausente/não funcional: integração opcional indisponível; Java pode continuar.'
        return 0
    fi
    list=$("$cw_code" --list-extensions 2>/dev/null) || { cw_log REVIEW 'Não foi possível listar extensões Java.'; return 0; }
    while IFS= read -r extension; do
        case "$extension" in ''|'#'*) continue ;; esac
        [[ "$extension" =~ ^[a-zA-Z0-9-]+\.[a-zA-Z0-9-]+$ ]] || return 1
        if printf '%s\n' "$list" | grep -Fxiq "$extension"; then cw_log SKIP "VS Code Java: $extension"
        else
            cw_log REVIEW "VS Code Java: $extension ausente; instalação opcional exige aprovação individual no perfil padrão."
            java_extensions[${#java_extensions[@]}]=$extension
        fi
    done < "$CW_ROOT/manifests/java-extensions.txt"
}
cw_java_editor_apply() {
    local extension list
    for extension in ${java_extensions[@]+"${java_extensions[@]}"}; do
        list=$("$cw_code" --list-extensions) || return 1
        if printf '%s\n' "$list" | grep -Fxiq "$extension"; then continue; fi
        cw_log PLAN "Aprovar extensão Java $extension no perfil padrão (pode incluir dependências declaradas pelo editor)? Perfil ativo e settings preservados."
        cw_confirm || continue
        "$cw_code" --install-extension "$extension" || return 1
        list=$("$cw_code" --list-extensions) || return 1
        printf '%s\n' "$list" | grep -Fxiq "$extension" || return 1
    done
}
