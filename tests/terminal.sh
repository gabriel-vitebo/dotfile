#!/bin/bash
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/cw-terminal.XXXXXX")
sandbox=$(cd "$sandbox" && pwd -P)
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox/home"
unset ZSH ZDOTDIR NVM_DIR
export SHELL=/bin/zsh
mkdir -p "$HOME" "$sandbox/source"
cp -R "$root/bin" "$root/lib" "$root/modules" "$root/platforms" "$root/manifests" "$root/install.sh" "$sandbox/source/"
CW_ROOT="$sandbox/source"
. "$CW_ROOT/lib/setup.sh"
. "$CW_ROOT/modules/terminal.sh"
checks=0
pass() { checks=$((checks + 1)); printf 'ok %s - %s\n' "$checks" "$*"; }
if cw_terminal_theme "$CW_ROOT/manifests/terminal/zshrc"; then exit 1; fi
printf 'ZSH_THEME=robbyrussell\nsource "$ZSH/oh-my-zsh.sh"\n' > "$sandbox/captured"
cw_terminal_theme "$sandbox/captured" | grep -qx robbyrussell
printf 'ZSH_THEME=random\n' > "$sandbox/unknown"
if cw_terminal_theme "$sandbox/unknown"; then exit 1; fi
pass 'tema capturado e tema desconhecido'
for tool in zsh vim; do cw_probe "$tool"; done
cw_probe nonexistent-cw-command && exit 1
broken() { return 1; }
state=0; cw_probe broken || state=$?; [ "$state" -eq 2 ]
pass 'sondagem de ferramentas funcionais, ausentes e quebradas'
state=0; cw_terminal_omz_probe "$HOME/.oh-my-zsh" || state=$?; [ "$state" -eq 1 ]
mkdir -p "$HOME/.oh-my-zsh/lib" "$HOME/.oh-my-zsh/themes" "$HOME/.oh-my-zsh/plugins/git"
state=0; cw_terminal_omz_probe "$HOME/.oh-my-zsh" || state=$?; [ "$state" -eq 2 ]
for file in oh-my-zsh.sh lib/git.zsh lib/theme-and-appearance.zsh themes/robbyrussell.zsh-theme plugins/git/git.plugin.zsh; do
    printf ': # fixture\n' > "$HOME/.oh-my-zsh/$file"
done
cw_terminal_omz_probe "$HOME/.oh-my-zsh"
cw_terminal_asset_probe "$HOME/.oh-my-zsh/themes/robbyrussell.zsh-theme"
state=0; cw_terminal_asset_probe "$HOME/.oh-my-zsh/plugins/missing" || state=$?; [ "$state" -eq 1 ]
pass 'framework, tema e plugins presentes, ausentes e incompletos'
printf "alias personal='echo portable'\n" > "$HOME/.zshrc"
cp "$HOME/.zshrc" "$sandbox/original"
dry=1
cw_terminal_file "$HOME/.config/config-workplace-terminal/zshrc" "$CW_ROOT/manifests/terminal/zshrc" > "$sandbox/dry"
cw_terminal_file "$HOME/.zshrc" '' startup >> "$sandbox/dry"
[ ! -d "$HOME/.config" ]; cmp "$HOME/.zshrc" "$sandbox/original"
pass 'dry-run de arquivos sem mutações'
dry=0
printf 'n\n' | cw_terminal_file "$HOME/.zshrc" '' startup > "$sandbox/decline"
cmp "$HOME/.zshrc" "$sandbox/original"
pass 'recusa preserva arquivo'
printf 's\n' | cw_terminal_file "$HOME/.config/config-workplace-terminal/zshrc" "$CW_ROOT/manifests/terminal/zshrc" > "$sandbox/apply"
printf 's\n' | cw_terminal_file "$HOME/.zshrc" '' startup >> "$sandbox/apply"
grep -q BACKUP "$sandbox/apply"
for backup in "$HOME"/.zshrc.config-workplace-backup.*; do cmp "$backup" "$sandbox/original"; done
zsh -f -n "$HOME/.zshrc"
pass 'aplicação com backup exato e sintaxe válida'
cw_terminal_file "$HOME/.zshrc" '' startup </dev/null > "$sandbox/idempotent"
cw_terminal_file "$HOME/.config/config-workplace-terminal/zshrc" "$CW_ROOT/manifests/terminal/zshrc" </dev/null >> "$sandbox/idempotent"
[ "$(grep -c SKIP "$sandbox/idempotent")" -eq 2 ]
pass 'idempotência de bloco e arquivo idêntico'
printf '# alteração local\n' >> "$HOME/.config/config-workplace-terminal/zshrc"
printf 'n\n' | cw_terminal_file "$HOME/.config/config-workplace-terminal/zshrc" "$CW_ROOT/manifests/terminal/zshrc" > "$sandbox/diff"
grep -q 'alteração local' "$sandbox/diff"
pass 'diff e recusa de fragmento divergente'
printf 'source other-framework\n' > "$HOME/conflict"
cw_terminal_file "$HOME/conflict" '' startup > "$sandbox/conflict"
grep -q 'integração manual' "$sandbox/conflict"
ln -s "$HOME/.zshrc" "$HOME/link"
cw_terminal_file "$HOME/link" '' startup > "$sandbox/link"
grep -q 'Link preservado' "$sandbox/link"
pass 'conflitos e symlinks preservados'
# Package adapters mocked: no network, sudo or real package manager.
(
 cw_probe() { return 1; }
 cw_tool_probe() { if [ "${installed:-0}" -eq 1 ]; then return 0; else return 1; fi; }
 dpkg-query() { return 1; }
 cw_privileged() { printf '%s\n' "$*" >> "$sandbox/apt"; installed=1; }
 cw_os=ubuntu
 cw_install_tool zsh
)
grep -q 'apt-get install --no-upgrade -y zsh' "$sandbox/apt"
(
 cw_probe() { return 0; }
 cw_tool_probe() { if [ "${installed:-0}" -eq 1 ]; then return 0; else return 1; fi; }
 brew() { [ "$HOMEBREW_NO_AUTO_UPDATE" = 1 ]; [ "$HOMEBREW_NO_INSTALL_UPGRADE" = 1 ]; installed=1; }
 cw_os=macos
 cw_install_tool vim
)
pass 'adaptadores Ubuntu/macOS sem instalação real'
if grep -REn '/Users/|/opt/homebrew|TOKEN=|PASSWORD=|PRIVATE KEY|alias .*=(.*brew|.*open )' "$CW_ROOT/manifests/terminal"; then exit 1; fi
pass 'fragmentos sem caminhos do Mac, segredos conhecidos ou aliases exclusivos'
# Full planner does not create files, even with missing tools/framework.
(
 cw_platform() { cw_os=ubuntu; }
 cw_probe() { return 1; }
 export ZSH="$HOME/absent-omz"
 cw_terminal --dry-run > "$sandbox/missing-plan"
)
[ ! -e "$HOME/absent-omz" ]
grep -q 'INSTALL.*zsh' "$sandbox/missing-plan"
grep -q 'INSTALL.*vim' "$sandbox/missing-plan"
pass 'plano completo com Zsh/Vim/framework ausentes sem instalação'
# Exercise OMZ installation with a fixture download, no real Git/network.
(
 git() {
   case "$1" in
     --version) echo fixture-git ;;
     clone) cp -R "$HOME/.oh-my-zsh" "$5" ;;
     -C) if [ "$3" = rev-parse ]; then echo fixture-commit; fi ;;
     *) return 1 ;;
   esac
 }
 cw_terminal_install_omz "$HOME/new-omz"
 cw_terminal_omz_probe "$HOME/new-omz"
 cw_terminal_install_omz "$HOME/new-omz"
) > "$sandbox/omz-install"
pass 'framework ausente instalado e reexecução preservada com download simulado'
(
 cw_platform() { cw_os=macos; }
 chsh() { echo called > "$sandbox/chsh"; }
 cw_terminal --dry-run --change-shell > "$sandbox/shell-plan"
)
[ ! -e "$sandbox/chsh" ]
pass 'troca de shell nunca executada no dry-run'
# The fragment can precede/follow a personal startup without loading OMZ itself.
mkdir -p "$sandbox/personal-omz" "$sandbox/personal-nvm"
printf '(( omz_count += 1 ))\n' > "$sandbox/personal-omz/oh-my-zsh.sh"
printf 'nvm() { :; }\n(( nvm_count += 1 ))\n' > "$sandbox/personal-nvm/nvm.sh"
printf '(( completion_count += 1 ))\n' > "$sandbox/personal-nvm/bash_completion"
cat > "$sandbox/personal-startup" <<'ZSH'
ZSH_THEME='personal/custom'
plugins=(git personal-plugin)
alias mine='echo personal'
PROMPT='custom appearance even for a known theme'
source "$FRAGMENT"
source "$ZSH/oh-my-zsh.sh"
source "$FRAGMENT"
[[ "$ZSH_THEME" = personal/custom && "${plugins[*]}" = 'git personal-plugin' ]]
[[ "$PROMPT" = 'custom appearance even for a known theme' ]]
[[ "$aliases[mine]" = 'echo personal' ]]
(( omz_count == 1 && nvm_count == 1 && completion_count == 1 ))
local_count=0
for entry in "${path[@]}"; do
    [[ "$entry" != "$HOME/.local/bin" ]] || (( local_count += 1 ))
done
(( local_count == 1 ))
ZSH
FRAGMENT="$CW_ROOT/manifests/terminal/zshrc" ZSH="$sandbox/personal-omz" NVM_DIR="$sandbox/personal-nvm" zsh -f -e "$sandbox/personal-startup"
pass 'tema, prompt, aliases, plugins e PATH preservados; OMZ/NVM/completion sem duplicação'
(
    export CW_DOTFILES_REPO="$sandbox/permanent-repository"
    mkdir -p "$CW_DOTFILES_REPO/manifests/terminal"
    cp "$CW_ROOT/manifests/terminal/zshrc" "$CW_DOTFILES_REPO/manifests/terminal/zshrc"
    payload="$HOME/.config/config-workplace-terminal/zshrc"
    cp "$payload" "$sandbox/payload-before"
    rm "$payload"
    ln -s "$CW_DOTFILES_REPO/manifests/terminal/zshrc" "$payload"
    cp "$HOME/.zshrc" "$sandbox/rc-before"
    cw_terminal_file "$payload" "$sandbox/unknown" > "$sandbox/managed"
    cw_install_tool() { exit 99; }
    cw_terminal_install_omz() { exit 99; }
    cw_terminal_install_asset() { exit 99; }
    chsh() { exit 99; }
    cw_terminal > "$sandbox/managed-module"
    [ -L "$payload" ]
    cmp "$CW_DOTFILES_REPO/manifests/terminal/zshrc" "$CW_ROOT/manifests/terminal/zshrc"
    cmp "$HOME/.zshrc" "$sandbox/rc-before"
    grep -q 'link gerenciado' "$sandbox/managed"
    rm "$payload"
    cp "$sandbox/payload-before" "$payload"
)
pass 'helper e módulo preservam link gerenciado, fonte e startup sem instalar assets'
PATH="$HOME/.local/bin:$PATH" /bin/bash "$CW_ROOT/install.sh" </dev/null > "$sandbox/bootstrap"
rm -rf "$CW_ROOT"
"$HOME/.local/bin/config-workplace" terminal --dry-run > "$sandbox/permanent"
grep -q 'Dry-run' "$sandbox/permanent"
rm -rf "$HOME/.local/share/config-workplace"
(cd / && SHELL_SESSIONS_DISABLE=1 ZDOTDIR="$HOME" zsh -i -c 'alias personal; [[ -z "${ZSH_THEME:-}" ]]' > "$sandbox/startup" 2> "$sandbox/stderr")
cat "$sandbox/stderr"
[ ! -s "$sandbox/stderr" ]
grep -q portable "$sandbox/startup"
pass 'nova sessão sem clone nem CLI, aliases locais preservados'
printf '%s verificações concluídas.\n' "$checks"
