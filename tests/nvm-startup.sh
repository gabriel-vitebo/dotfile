#!/bin/bash
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export HOME="$work/home" SHELL=/bin/bash
mkdir -p "$HOME"
CW_ROOT=$root
. "$root/lib/setup.sh"
. "$root/lib/dev-safety.sh"
export NVM_DIR="$HOME/custom nvm"
mkdir -p "$NVM_DIR/bin"
printf '#!/bin/sh\necho mock\n' > "$NVM_DIR/bin/node"
cp "$NVM_DIR/bin/node" "$NVM_DIR/bin/npm"
chmod +x "$NVM_DIR/bin/"*
cat > "$NVM_DIR/nvm.sh" <<'NVM'
nvm() { echo 0.40.8; }
case "${1:-}" in --no-use) ;; *) export PATH="$NVM_DIR/bin:$PATH" ;; esac
NVM
cw_load_nvm
[ "$NVM_DIR" = "$HOME/custom nvm" ]
unset -f nvm
cw_nvm_shell_plan > "$work/plan"
[ ! -e "$HOME/.bashrc" ]; grep -q 'export NVM_DIR=' "$work/plan"
cw_nvm_shell_apply <<< n
[ ! -e "$HOME/.bashrc" ]
cw_nvm_shell_apply <<< s
bash --noprofile --rcfile "$HOME/.bashrc" -ic 'command -v nvm && node --version && npm --version' > "$work/session" 2>&1
grep -q mock "$work/session"
cw_nvm_shell_plan; [ "$nvm_startup_pending" -eq 0 ]
printf '# personal\nexport PERSONAL=yes\n' > "$HOME/.bashrc"
chmod 640 "$HOME/.bashrc"
cp -p "$HOME/.bashrc" "$work/before"
cw_nvm_shell_plan; cw_nvm_shell_apply <<< n
cmp "$work/before" "$HOME/.bashrc"
cw_nvm_shell_apply <<< s
for backup in "$HOME/.bashrc.config-workplace-backup."*; do cmp "$backup" "$work/before"; done
[ "$(stat -c %a "$HOME/.bashrc" 2>/dev/null || stat -f %Lp "$HOME/.bashrc")" = 640 ]
grep -q '^export PERSONAL=yes$' "$HOME/.bashrc"
printf '. "$NVM_DIR/nvm.sh"\n' > "$HOME/.bashrc"
cw_nvm_shell_plan > "$work/review"; grep -q REVIEW "$work/review"
[ "$nvm_startup_pending" -eq 0 ]
rm "$HOME/.bashrc"
ln -s "$work/before" "$HOME/.bashrc"
cw_nvm_shell_plan; [ "$nvm_startup_pending" -eq 0 ]; cmp "$work/before" "$HOME/.bashrc"
for location in "$HOME" "$HOME/z dot"; do
    export SHELL=/bin/zsh ZDOTDIR="$location"
    mkdir -p "$location"
    printf '# personal zsh\n' > "$location/.zshrc"
    cw_nvm_shell_plan; [ "$nvm_startup_file" = "$location/.zshrc" ]
    cw_nvm_shell_apply <<< s
    grep -q '^# personal zsh$' "$location/.zshrc"
    cw_nvm_shell_plan; [ "$nvm_startup_pending" -eq 0 ]
    if command -v zsh >/dev/null; then zsh -ic 'command -v nvm && node --version && npm --version'; fi
done
# Delete a disposable source clone; startup contains only the independent NVM path.
mkdir "$work/clone"
CW_ROOT="$work/clone"
export SHELL=/bin/bash
rm "$HOME/.bashrc"
cw_nvm_shell_plan; cw_nvm_shell_apply <<< s
rmdir "$work/clone"
bash --noprofile --rcfile "$HOME/.bashrc" -ic 'nvm --version && node --version && npm --version' > "$work/session" 2>&1
grep -q mock "$work/session"
printf 'OK: NVM startup, dry plan, recusa, backups, permissões, links, ZDOTDIR e nova sessão sem clone.\n'
