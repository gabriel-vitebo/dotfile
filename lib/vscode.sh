. "$CW_ROOT/lib/dotfiles.sh"
cw_settings_path() { cw_settings=$(cw_df_destination vscode); }
cw_settings() { node "$CW_ROOT/lib/vscode-settings.js" "$1" "$cw_settings" "$CW_ROOT/manifests/vscode-settings.json" "$CW_ROOT" "${2:-}" "${3:-}"; }
cw_editor_plan() {
    local extension list report pending=0
    cw_settings_path
    if [ -n "$cw_code" ] && list=$("$cw_code" --list-extensions 2>/dev/null); then
        while IFS= read -r extension <&3; do
            case "$extension" in ''|'#'*) continue ;; esac
            if printf '%s\n' "$list" | grep -Fxiq "$extension"; then cw_log SKIP "Extensão $extension"
            else cw_log PLAN "Extensão $extension (perfil padrão; não troca perfil ativo)"; pending=1; fi
        done 3< "$CW_ROOT/manifests/vscode-extensions.txt"
    else cw_log REVIEW 'Extensões: inventário indisponível; verificar após instalar/recuperar CLI.'; pending=1; fi
    if cw_probe node; then
        report=$(cw_settings plan) || true
        printf '%s\n' "$report"
        case "$report" in *'[REVIEW]'*) pending=1 ;; esac
    else cw_log REVIEW 'Settings: revisão adiada até Node funcional.'; pending=1; fi
    [ "$pending" -eq 0 ] || actions[${#actions[@]}]=editor
}
cw_editor_apply() {
    local extension list report key digest
    if cw_vscode_probe && list=$("$cw_code" --list-extensions 2>/dev/null); then
        while IFS= read -r extension <&3; do
            case "$extension" in ''|'#'*) continue ;; esac
            [[ "$extension" =~ ^[a-zA-Z0-9-]+\.[a-zA-Z0-9-]+$ ]] || return 1
            if printf '%s\n' "$list" | grep -Fxiq "$extension"; then cw_log SKIP "Extensão $extension"; continue; fi
            cw_log PLAN "Instalar extensão $extension no perfil padrão (sem --profile/--force)"
            cw_confirm || continue
            list=$("$cw_code" --list-extensions) || return 1
            if printf '%s\n' "$list" | grep -Fxiq "$extension"; then continue; fi
            "$cw_code" --install-extension "$extension" || return 1
            list=$("$cw_code" --list-extensions) || return 1
            printf '%s\n' "$list" | grep -Fxiq "$extension" || return 1
        done 3< "$CW_ROOT/manifests/vscode-extensions.txt"
    else cw_log REVIEW 'Extensões preservadas; CLI não disponível.'; fi
    cw_probe node || { cw_log REVIEW 'Settings requer Node funcional.'; return 0; }
    cw_settings_path
    report=$(cw_settings keys) || { printf '%s\n' "$report"; return 0; }
    while IFS= read -r key <&4; do
        digest=$(cw_settings hash) || return 1
        report=$(cw_settings plan "$key") || return 1
        printf '%s\n' "$report"
        case "$report" in '[SKIP]'*) continue ;; esac
        cw_confirm || continue
        cw_settings apply "$key" "$digest" || return 1
    done 4<<< "$report"
}
