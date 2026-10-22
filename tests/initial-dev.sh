#!/bin/bash
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
sandbox=$(mktemp -d "$root/tests/.initial-dev.XXXXXX")
trap 'result=$?; if [ "$result" -ne 0 ]; then tail -n 30 "$sandbox/output"; fi; rm -rf "$sandbox"' EXIT
export HOME="$sandbox/home" TMPDIR="$sandbox"
unset NVM_DIR
mkdir -p "$HOME"
CW_ROOT=$root
. "$root/lib/setup.sh"
. "$root/modules/initial-dev.sh"
# The only allowlisted dotfile remains unchanged through every legacy operation.
. "$root/lib/dotfiles.sh"
export CW_DOTFILES_REPO="$sandbox/permanent repository"
mkdir -p "$CW_DOTFILES_REPO/manifests/terminal" "$HOME/.config/config-workplace-terminal"
cp "$root/manifests/terminal/zshrc" "$CW_DOTFILES_REPO/manifests/terminal/zshrc"
ln -s "$CW_DOTFILES_REPO/manifests/terminal/zshrc" "$HOME/.config/config-workplace-terminal/zshrc"
cw_df_terminal_link "$HOME/.config/config-workplace-terminal/zshrc"
printf '# personal startup\n' > "$HOME/.zshrc"
cp "$HOME/.zshrc" "$sandbox/startup-before"
# Phase 2.1 regression tests isolate the new planning boundary.
cw_dev_plan() { :; }
checks=0
pass() { checks=$((checks + 1)); printf 'ok %s - %s\n' "$checks" "$*"; }
# Every mutating boundary is mocked; all state stays under the repository.
reset() {
    : > "$sandbox/mutations"
    missing= broken= platform=macos lts=22 node_major=22 local_node=N/A
    fail_install=0
    installed='git gh nvm node npm'
}
has() { case " $installed " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
cw_probe() {
    cw_version=1.0
    [ "$1" != node ] || cw_version="v$node_major.1.0"
    [ "$1" != "$broken" ] || return 2
    has "$1" || [ "$1" = brew ]
}
cw_platform() { cw_os=$platform; cw_arch=x86_64; }
cw_lts_major() { printf '%s\n' "$lts"; }
cw_load_nvm() { has nvm; }
cw_package() {
    printf 'package %s\n' "$1" >> "$sandbox/mutations"
    [ "$fail_install" -eq 0 ] || return 1
    installed="$installed $1"
}
cw_install_nvm() { echo nvm >> "$sandbox/mutations"; installed="$installed nvm"; }
node() { [ "$1" != -p ] || echo MockLTS; }
gh() { return 1; }
nvm() {
    case "$1" in
        --version) echo 0.40.0 ;;
        version) echo "$local_node" ;;
        install) echo 'node install' >> "$sandbox/mutations"; installed="$installed node npm" ;;
        use) echo 'node use' >> "$sandbox/mutations"; installed="$installed node npm" ;;
        alias) echo alias >> "$sandbox/mutations" ;;
    esac
}
run() { cw_initial_dev "$@" > "$sandbox/output" 2>&1; }
reset
run </dev/null
[ ! -s "$sandbox/mutations" ]; grep -q 'fora do NVM' "$sandbox/output"
pass 'Git, gh, NVM, Node externo LTS e npm funcionais: nenhuma instalação'
run </dev/null
[ ! -s "$sandbox/mutations" ]
pass 'reexecução idempotente sem confirmação'
for tool in git gh nvm; do
    reset; installed=${installed/$tool/}
    run --dry-run </dev/null
    [ ! -s "$sandbox/mutations" ]; grep -q "Instalar $tool" "$sandbox/output"
    run <<< n
    [ ! -s "$sandbox/mutations" ]
    run <<< s
    grep -q "$tool" "$sandbox/mutations"
    pass "$tool ausente: dry-run, recusa e instalação autorizada"
done
reset; installed='git gh nvm'; unset -f node
run --dry-run </dev/null
[ ! -s "$sandbox/mutations" ]
# Hide the real Node in PATH only during the mutation recheck.
node_path=$PATH
PATH=/usr/bin:/bin:/usr/sbin:/sbin
run <<< s
PATH=$node_path
grep -q 'node install' "$sandbox/mutations"
pass 'Node ausente: instalação via NVM e verificação npm'
reset; installed='git gh nvm'; local_node=v22.1.0
run <<< s
grep -q 'node use' "$sandbox/mutations"
if grep -q 'node install' "$sandbox/mutations"; then exit 1; fi
pass 'Node LTS disponível no NVM é reutilizado sem download'
node() { [ "$1" != -p ] || echo MockLTS; }
reset; node_major=20
if run </dev/null; then exit 1; fi
[ ! -s "$sandbox/mutations" ]; grep -q -- '--approve-node-change' "$sandbox/output"
run --approve-node-change <<< n
[ ! -s "$sandbox/mutations" ]
run --approve-node-change <<< s
grep -q 'node install' "$sandbox/mutations"
pass 'Node divergente exige autorização específica e confirmação'
reset; lts=
if run --dry-run; then exit 1; fi
[ ! -s "$sandbox/mutations" ]
pass 'falha de resolução LTS preserva o computador'
for tool in git gh node npm; do
    reset; broken=$tool
    if run <<< s; then exit 1; fi
    [ ! -s "$sandbox/mutations" ]
    pass "$tool existente com falha não é reinstalado"
done
reset; installed='git nvm node npm'; fail_install=1
if run <<< s; then exit 1; fi
grep -q '\[FAIL\]' "$sandbox/output"
pass 'falha de instalação não informa sucesso'
# Exercise the real reusable guard and package adapters with fake executables.
. "$root/lib/setup.sh"
git() { printf 'git version mock\n'; }
brew() { echo "brew $*" >> "$sandbox/mutations"; }
cw_os=macos
: > "$sandbox/mutations"
cw_package git
[ ! -s "$sandbox/mutations" ]
pass 'guard compartilhado preserva Git funcional independentemente da origem'
git() { return 1; }
if cw_package git; then exit 1; fi
[ ! -s "$sandbox/mutations" ]
pass 'guard compartilhado bloqueia ferramenta quebrada'
# Test real platform detection while controlling OS metadata via a read-only helper mock.
uname() { case "$1" in -m) echo arm64 ;; -s) echo Darwin ;; esac; }
cw_platform; [ "$cw_os" = macos ]
uname() { case "$1" in -m) echo unsupported ;; -s) echo Darwin ;; esac; }
if cw_platform; then exit 1; fi
pass 'detecção macOS e bloqueio de arquitetura desconhecida'
# Existing NVM is a shell function, not an executable.
cw_load_nvm
pass 'NVM carregado como função é reutilizado'
unset -f nvm
mkdir -p "$HOME/.nvm"
printf 'nvm() { echo 0.40.0; }\n' > "$HOME/.nvm/nvm.sh"
cw_load_nvm
[ "$NVM_DIR" = "$HOME/.nvm" ]
pass 'NVM existente em disco é carregado sem reinstalação'
for file in "$root"/lib/*.sh "$root"/modules/*.sh "$root"/tests/*.sh; do /bin/bash -n "$file"; done
pass 'sintaxe Bash'
# Actual adapters, no package manager or privileged command can reach the host.
uname() { case "$1" in -m) echo x86_64 ;; -s) echo Linux ;; esac; }
cw_is_ubuntu() { return 0; }
cw_platform; [ "$cw_os" = ubuntu ]
cw_is_ubuntu() { return 1; }
if cw_platform; then exit 1; fi
pass 'Ubuntu detectado e outras distribuições recusadas'
cw_probe() { if [ -f "$sandbox/package-ready" ]; then cw_version=mock; return 0; else return 1; fi; }
cw_privileged() { echo "$*" >> "$sandbox/mutations"; case "$*" in *install*) : > "$sandbox/package-ready" ;; esac; }
cw_os=ubuntu
: > "$sandbox/mutations"
cw_package git
grep -q 'apt-get install -y git' "$sandbox/mutations"
rm "$sandbox/package-ready"
cw_gh_repository() { echo repository >> "$sandbox/mutations"; }
cw_package gh
grep -q repository "$sandbox/mutations"
grep -q 'apt-get install -y gh' "$sandbox/mutations"
pass 'APT instala ausentes e gh prepara repositório oficial'
rm "$sandbox/package-ready"
cw_os=macos
brew() { echo "brew $*" >> "$sandbox/mutations"; : > "$sandbox/package-ready"; }
cw_package gh
grep -q 'brew install gh' "$sandbox/mutations"
pass 'Homebrew instala somente ferramenta ausente'
# Validate the NVM installer boundary using an entirely local fake release.
. "$root/lib/setup.sh"
cw_load_nvm() { return 1; }
CW_ROOT="$sandbox/source-clone"
export NVM_DIR="$HOME/new-nvm"
curl() { echo https://github.com/nvm-sh/nvm/releases/tag/v99.1.0; }
git() {
    case "$1" in
        clone)
            for destination in "$@"; do :; done
            mkdir -p "$destination"
            cat > "$destination/install.sh" <<'INSTALLER'
#!/bin/bash
[ "$PROFILE" = /dev/null ] && [ -z "$NODE_VERSION" ] && [ -z "$NVM_ENV" ] || exit 1
printf 'validated installer\n' > "$NVM_DIR/installed"
INSTALLER
            ;;
        -C)
            case "$3" in
                fsck) [ "${bad_release:-0}" -eq 0 ] ;;
                rev-parse) echo mock-commit ;;
                remote) echo official-origin >> "$sandbox/mutations" ;;
            esac ;;
    esac
}
export NODE_VERSION=unexpected NVM_ENV=_testing
cw_install_nvm
[ -f "$NVM_DIR/installed" ]
grep -q official-origin "$sandbox/mutations"
pass 'NVM: instalador validado, ambiente controlado e origem independente'
export NVM_DIR="$HOME/rejected-nvm"
bad_release=1
if cw_install_nvm; then exit 1; fi
[ ! -e "$NVM_DIR" ]
pass 'NVM: falha de validação impede execução do instalador'
cw_df_terminal_link "$HOME/.config/config-workplace-terminal/zshrc"
cmp "$root/manifests/terminal/zshrc" "$CW_DOTFILES_REPO/manifests/terminal/zshrc"
cmp "$HOME/.zshrc" "$sandbox/startup-before"
pass 'initial dev e NVM preservam ownership, fonte e startup em todas as operações'
printf '\n%s verificações concluídas.\n' "$checks"
