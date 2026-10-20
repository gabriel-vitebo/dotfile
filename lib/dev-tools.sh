# Phase 2.2 detection: 0 healthy, 1 absent, 2 present but needs review.
cw_tool_probe() {
    local name=$1 cmd=$1
    cw_version=
    case "$name" in
        build-essential)
            if [ "$cw_os" = macos ]; then
                xcode-select -p >/dev/null 2>&1 || return 1
            fi
            command -v cc >/dev/null 2>&1 || return 1
            command -v c++ >/dev/null 2>&1 || return 1
            command -v make >/dev/null 2>&1 || return 1
            cc --version >/dev/null 2>&1 && c++ --version >/dev/null 2>&1 && make --version >/dev/null 2>&1 || return 2
            cw_version='cc, c++, make'; return 0 ;;
        ca-certificates)
            if [ "$cw_os" = macos ]; then
                [ -s /System/Library/Keychains/SystemRootCertificates.keychain ] || return 2
            else
                [ -s /etc/ssl/certs/ca-certificates.crt ] || return 1
            fi
            cw_version='system trust store'; return 0 ;;
        unzip|ssh)
            command -v "$cmd" >/dev/null 2>&1 || return 1
            if [ "$cmd" = unzip ]; then cw_version=$(unzip -v 2>&1) || return 2
            else cw_version=$(ssh -V 2>&1) || return 2; fi
            [ -n "$cw_version" ] || return 2; return 0 ;;
    esac
    if [ "$name" = pnpm ]; then
        command -v pnpm >/dev/null 2>&1 || return 1
        cw_version=$(cd "$HOME" && COREPACK_ENABLE_NETWORK=0 COREPACK_ENABLE_AUTO_PIN=0 npm_config_manage_package_manager_versions=false pnpm --version 2>/dev/null) || return 2
        [ -n "$cw_version" ] || return 2
        return 0
    fi
    cw_probe "$cmd"
}
cw_vscode_probe() {
    local candidate
    cw_code=; cw_code_origin=
    if command -v code >/dev/null 2>&1; then
        cw_code=$(command -v code); cw_code_origin=$cw_code
        cw_probe "$cw_code" && return 0
        return 2
    fi
    for candidate in "${CW_VSCODE_APP:-/Applications/Visual Studio Code.app}/Contents/Resources/app/bin/code" \
        "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" \
        /usr/share/code/bin/code /snap/bin/code /opt/visual-studio-code/bin/code; do
        [ -e "$candidate" ] || continue
        cw_code=$candidate; cw_code_origin=$candidate
        cw_probe "$candidate" && return 0
        return 2
    done
    if [ -d "${CW_VSCODE_APP:-/Applications/Visual Studio Code.app}" ] || \
       [ -d "$HOME/Applications/Visual Studio Code.app" ] || \
       { command -v dpkg-query >/dev/null && dpkg-query -W -f='${Status}' code 2>/dev/null | grep -q 'install ok installed'; } || \
       { command -v snap >/dev/null && snap list code >/dev/null 2>&1; } || \
       { command -v flatpak >/dev/null && flatpak info com.visualstudio.code >/dev/null 2>&1; }; then
        cw_code_origin='aplicativo/pacote existente'; return 2
    fi
    return 1
}
cw_dev_plan() {
    local name state planned_node=0 action
    review_pending=0
    for action in ${actions[@]+"${actions[@]}"}; do
        [ "$action" != node ] || planned_node=1
    done
    for name in curl wget unzip jq rg fzf build-essential ca-certificates ssh pnpm; do
        state=0; cw_tool_probe "$name" || state=$?
        case "$state" in
            0) cw_log SKIP "$name: ${cw_version%%$'\n'*} (${name}: $(command -v "$name" || true))" ;;
            1)
                if [ "$name" = pnpm ]; then
                    pnpm_version=
                    if [ "$planned_node" -eq 0 ] && cw_probe node && command -v curl >/dev/null; then
                        if ! cw_resolve_pnpm; then review_pending=1; cw_log REVIEW 'pnpm não será instalado; revise compatibilidade/rede e reexecute.'; continue; fi
                    fi
                    cw_log PLAN "pnpm ${pnpm_version:-a resolver após Node/curl, com nova confirmação}: npm isolado em ~/.local/share/config-workplace-pnpm; PATH em nova sessão"
                fi
                actions[${#actions[@]}]="dev:$name"; cw_log PLAN "Instalar $name"
                if [ "$cw_os" = macos ]; then
                    case "$name" in
                        build-essential) cw_log PLAN 'Abrir instalador interativo Apple: xcode-select --install' ;;
                        ca-certificates|ssh) cw_log REVIEW 'Componente nativo: reparo manual necessário' ;;
                        pnpm) ;;
                        *) cw_probe brew || cw_log REVIEW "Homebrew necessário para $name; não será instalado automaticamente" ;;
                    esac
                elif [ "$name" != pnpm ]; then cw_log PLAN "$name via APT (pode exigir sudo; sem upgrade explícito)"; fi ;;
            *) review_pending=1; cw_log REVIEW "$name presente com problema; preservado, reparo manual necessário." ;;
        esac
    done
    state=0; cw_vscode_probe || state=$?
    case "$state" in
        0) cw_log SKIP "VS Code: ${cw_version%%$'\n'*} ($cw_code_origin)"
           if ! command -v code >/dev/null; then
               cw_log REVIEW 'VS Code CLI fora do PATH; proposta: criar lançador em ~/.local/bin/code.'
               actions[${#actions[@]}]=code-cli
           fi ;;
        1) cw_log PLAN 'Instalar VS Code estável'; actions[${#actions[@]}]=vscode ;;
        *) review_pending=1; cw_log REVIEW "VS Code existente ($cw_code_origin), CLI não funcional; instalação preservada." ;;
    esac
    cw_editor_plan
}
cw_install_tool() {
    local state=0 name=$1 package=$1
    cw_tool_probe "$name" || state=$?
    [ "$state" -ne 0 ] || { cw_log SKIP "$name já funcional"; return 0; }
    [ "$state" -eq 1 ] || { cw_log REVIEW "$name preservado; falha na sondagem"; return 1; }
    [ "$name" != pnpm ] || { cw_install_pnpm; return $?; }
    case "$name" in rg) package=ripgrep ;; ssh) package=openssh-client ;; esac
    if [ "$cw_os" = macos ]; then
        case "$name" in
            build-essential)
                xcode-select --install || return 1
                cw_log REVIEW 'Instalador dos Command Line Tools aberto. Conclua a interface e reexecute para verificar.'
                return 0 ;;
            ca-certificates|ssh) cw_log MANUAL "$name: reparar componente nativo explicitamente."; return 1 ;;
        esac
        cw_probe brew || { cw_log MANUAL 'Homebrew ausente/não funcional; instale manualmente.'; return 1; }
        HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1 brew install "$package" || return 1
    else
        # A registered but unusable package is a repair, not an absent tool.
        if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed'; then
            cw_log REVIEW "$package já registrado no APT; investigar PATH/integridade."; return 1
        fi
        cw_privileged apt-get update && cw_privileged apt-get install --no-upgrade -y "$package" || return 1
    fi
    cw_tool_probe "$name"
}
cw_resolve_pnpm() {
    local metadata
    metadata=$(cw_fetch https://registry.npmjs.org/pnpm/latest) || return 1
    pnpm_version=$(printf '%s' "$metadata" | node "$CW_ROOT/lib/pnpm-metadata.js") || return 1
    [[ "$pnpm_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}
cw_install_pnpm() (
    # Only the pnpm package is installed, isolated from the active npm global prefix.
    cw_probe node && cw_probe npm || { cw_log REVIEW 'pnpm requer Node/npm funcionais; preservados.'; exit 1; }
    if [ -z "${pnpm_version:-}" ]; then
        cw_resolve_pnpm || exit 1
        cw_log PLAN "Instalar pnpm $pnpm_version compatível com o Node selecionado"
        cw_confirm || exit 0
    fi
    prefix="$HOME/.local/share/config-workplace-pnpm"
    node_bin=$(node -p 'process.execPath')
    case "$node_bin" in /*) ;; *) cw_log REVIEW 'Node deve ser executável com caminho absoluto.'; exit 1 ;; esac
    cw_safe_destination "$prefix" && cw_safe_destination "$HOME/.local/bin/pnpm" && cw_safe_destination "$node_bin" || exit 1
    [ ! -e "$prefix" ] && [ ! -L "$prefix" ] || { cw_log REVIEW "Destino existente: $prefix"; exit 1; }
    [ ! -e "$HOME/.local/bin/pnpm" ] && [ ! -L "$HOME/.local/bin/pnpm" ] || exit 1
    cw_local_path || exit 0
    # npm engine-strict checks the official latest package's declared Node requirement.
    # No --force, Corepack enable, npm upgrade, or Node replacement.
    mkdir -p "$HOME/.local/bin" || exit 1
    npm install --global --prefix "$prefix" --engine-strict --registry=https://registry.npmjs.org "pnpm@$pnpm_version" || exit 1
    "$prefix/bin/pnpm" --version || exit 1
    # Pin the interpreter path without changing the user's selected Node version.
    ( set -C; printf '#!/bin/bash\nexport PATH=%q:"$PATH"\nexec %q "$@"\n' "${node_bin%/*}" "$prefix/bin/pnpm" > "$HOME/.local/bin/pnpm" ) || exit 1
    chmod 755 "$HOME/.local/bin/pnpm" || exit 1
    "$HOME/.local/bin/pnpm" --version || exit 1
    cw_log OK 'pnpm em ~/.local/bin; mantenha esse diretório no PATH de novas sessões (bootstrap).'
)
