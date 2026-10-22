. "$CW_ROOT/lib/dev-safety.sh"
. "$CW_ROOT/lib/dev-tools.sh"
. "$CW_ROOT/lib/terminal-detect.sh"
. "$CW_ROOT/lib/terminal-files.sh"
. "$CW_ROOT/platforms/terminal-install.sh"

cw_terminal() (
    dry=0
    change_shell=0
    for arg in "$@"; do
        case "$arg" in --dry-run) dry=1 ;; --change-shell) change_shell=1 ;; *) cw_log FAIL "Opção inválida: $arg"; exit 2 ;; esac
    done
    cw_platform || exit 1
    theme=$(cw_terminal_preferred_theme) || exit 1
    omz=${ZSH:-$HOME/.oh-my-zsh}
    rc=${ZDOTDIR:-$HOME}/.zshrc
    payload="$HOME/.config/config-workplace-terminal/zshrc"
    bootstrap="$HOME/.config/config-workplace-terminal/bootstrap.zsh"
    cw_safe_destination "$omz" || exit 1
    [ "$(sed '/^#/d; /^$/d' "$CW_ROOT/manifests/terminal/plugins.txt")" = git ] || {
        cw_log REVIEW 'Manifesto de plugins não suportado; revisar antes de instalar.'; exit 1;
    }
    cw_log CHECK "Padrão versionado: $theme e git; bootstrap separado do fragmento portátil."
    if [ -f "$rc" ]; then
        detected=$(cw_terminal_theme "$rc" || true)
        cw_log CHECK "Tema local: ${detected:-não identificado estaticamente; preservar configuração}"
    fi
    actions=()
    for tool in zsh vim git; do
        state=0; cw_probe "$tool" || state=$?
        cw_terminal_report "$tool ${cw_version%%$'\n'*}" "$state"
        if [ "$state" -eq 1 ]; then
            actions[${#actions[@]}]=$tool
            if [ "$cw_os" = ubuntu ]; then cw_log PLAN "$tool via APT --no-upgrade (pode exigir sudo)"
            else cw_log PLAN "$tool via Homebrew existente; não instalar Homebrew"; fi
        fi
    done
    state=0; cw_terminal_omz_probe "$omz" || state=$?
    cw_terminal_report "Oh My Zsh em $omz" "$state"
    omz_state=$state
    for asset in themes/$theme.zsh-theme plugins/git/git.plugin.zsh; do
        state=0; cw_terminal_asset_probe "$omz/$asset" || state=$?
        cw_terminal_report "$asset" "$state"
        if [ "$state" -ne 0 ] && [ "$omz_state" -ne 1 ]; then
            cw_log REVIEW 'Componente do framework existente incompleto; ausentes podem ser obtidos com confirmação, inválidos exigem reparo manual.'
        fi
    done
    for custom in "${ZSH_CUSTOM:-$omz/custom}/$theme.zsh-theme" "${ZSH_CUSTOM:-$omz/custom}/themes/$theme.zsh-theme"; do
        [ ! -e "$custom" ] || cw_log REVIEW "Override local de $theme preservado: $custom; aparência requer revisão manual."
    done
    cw_log CHECK 'Vim: .vimrc e .vim ausentes na captura; nenhuma configuração ou plugin inventado.'
    [ ! -e "$HOME/.vimrc" ] || cw_log SKIP '.vimrc local preservado'
    [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ] || cw_log REVIEW 'NVM opcional ausente; carregamento condicional, instalação pertence a initial dev.'
    if [ "$dry" -eq 0 ]; then
        for tool in ${actions[@]+"${actions[@]}"}; do
            cw_log PLAN "Autorizar instalação de $tool?"
            if cw_confirm; then cw_install_tool "$tool" || exit 1; else cw_log SKIP "$tool recusado"; fi
        done
        if [ "$omz_state" -eq 1 ]; then
            cw_log PLAN "Instalar Oh My Zsh oficial, incluindo $theme e git, sem instalador externo e sem chsh"
            if cw_confirm; then cw_terminal_install_omz "$omz" || exit 1; else cw_log SKIP 'Oh My Zsh recusado'; fi
        fi
    fi
    if [ "$dry" -eq 0 ] && cw_terminal_omz_probe "$omz"; then
        for asset in themes/$theme.zsh-theme plugins/git/git.plugin.zsh; do
            state=0; cw_terminal_asset_probe "$omz/$asset" || state=$?
            if [ "$state" -eq 1 ]; then
                cw_log PLAN "Obter componente ausente $asset da fonte oficial (sem atualizar existentes)"
                if cw_confirm; then cw_terminal_install_asset "$omz/$asset" "$asset" || exit 1; fi
            fi
        done
    fi
    if [ "$dry" -eq 1 ] || { cw_probe zsh && cw_terminal_omz_probe "$omz" &&
        cw_terminal_asset_probe "$omz/themes/$theme.zsh-theme" &&
        cw_terminal_asset_probe "$omz/plugins/git/git.plugin.zsh"; }; then
        cw_terminal_file "$payload" "$CW_ROOT/manifests/terminal/zshrc" || exit 1
        cw_terminal_bootstrap || exit 1
    else cw_log REVIEW 'Configuração adiada até Zsh/framework/tema/plugin funcionais.'; fi
    if [ "$change_shell" -eq 1 ]; then
        shell_path=$(command -v zsh || true)
        if [ -n "$shell_path" ] && grep -Fxq "$shell_path" /etc/shells; then
            cw_log PLAN "Trocar shell padrão para $shell_path com chsh (confirmação específica)"
            if [ "$dry" -eq 0 ] && cw_confirm; then chsh -s "$shell_path" || exit 1; fi
        else cw_log REVIEW 'Zsh não disponível em /etc/shells; troca não autorizada.'; fi
    fi
    case "${SHELL:-}" in */zsh) ;; *)
        cw_log MANUAL 'Shell padrão diferente de Zsh. Para optar pela troca, execute terminal --change-shell e confirme especificamente. Pode usar zsh sem trocar o shell.' ;;
    esac
    if [ "$dry" -eq 1 ]; then cw_log OK 'Dry-run: nenhuma alteração executada.'
    else cw_log OK 'Revisão encerrada; consulte REVIEW/SKIP. Abra uma nova sessão Zsh para validar integrações locais.'; fi
)
