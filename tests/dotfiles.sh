#!/bin/bash
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
sandbox=$(mktemp -d)
sandbox=$(cd "$sandbox" && pwd -P)
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox/home with spaces"
export CW_DOTFILES_REPO="$sandbox/repository"
unset XDG_STATE_HOME XDG_DATA_HOME
mkdir -p "$HOME" "$CW_DOTFILES_REPO/manifests/terminal"
cp "$root/manifests/terminal/zshrc" "$CW_DOTFILES_REPO/manifests/terminal/zshrc"
dest="$HOME/.config/config-workplace-terminal/zshrc"
state="$HOME/.local/state/config-workplace/dotfiles"
cli() { /bin/bash "$root/bin/workspace" dotfiles "$@"; }
yes_cli() { printf 's\n' | cli "$@" > "$sandbox/output"; }
fail_cli() { if cli "$@" </dev/null > "$sandbox/output"; then echo 'Expected failure'; exit 1; fi; }
printf 'ZSH_THEME=personal\nalias mine=true\n' > "$HOME/.zshrc"
cp "$HOME/.zshrc" "$sandbox/startup"
cli link --dry-run > /dev/null
[ ! -e "$HOME/.config" ] && [ ! -e "$state" ]
yes_cli link
[ -L "$dest" ]; cli status > /dev/null
before=$(find "$state" -print | wc -l)
cli link </dev/null > /dev/null
[ "$before" = "$(find "$state" -print | wc -l)" ]
cmp "$HOME/.zshrc" "$sandbox/startup"
echo 'ok - dry-run, first link, repeat, status, personal startup'
yes_cli unlink
[ ! -L "$dest" ]; cli unlink </dev/null > /dev/null
printf personal > "$dest"
fail_cli link
[ "$(cat "$dest")" = personal ]
fail_cli unlink
rm "$dest"
ln -s "$HOME/.zshrc" "$dest"
fail_cli link; fail_cli unlink
[ "$(readlink "$dest")" = "$HOME/.zshrc" ]
rm "$dest"; ln -s "$HOME/missing" "$dest"
fail_cli link; fail_cli unlink
rm "$dest"; mkdir "$dest"
fail_cli link
rmdir "$dest"
echo 'ok - conflicts: file, foreign link, broken link, directory'
cp "$CW_DOTFILES_REPO/manifests/terminal/zshrc" "$dest"
chmod 640 "$dest"
cli link </dev/null > /dev/null
[ ! -L "$dest" ]
yes_cli link
found=0
for backup in "$state"/operation.*/original; do
    [ -f "$backup" ] || continue
    cmp "$backup" "$CW_DOTFILES_REPO/manifests/terminal/zshrc"
    [ "$(LC_ALL=C ls -l "$backup" | cut -c1-10)" = '-rw-r-----' ]
    found=1
done
[ "$found" = 1 ]
mv "$CW_DOTFILES_REPO/manifests/terminal/zshrc" "$sandbox/source"
fail_cli status
yes_cli unlink
mv "$sandbox/source" "$CW_DOTFILES_REPO/manifests/terminal/zshrc"
echo 'ok - confirmation, backup bytes/permissions, broken managed unlink'
# Inject a failure after the original copy has been backed up and removed.
cp "$CW_DOTFILES_REPO/manifests/terminal/zshrc" "$dest"
mkdir "$sandbox/mock"
printf '#!/bin/bash\nexit 71\n' > "$sandbox/mock/ln"
chmod +x "$sandbox/mock/ln"
if printf 's\n' | PATH="$sandbox/mock:$PATH" cli link > "$sandbox/output"; then exit 1; fi
[ ! -e "$dest" ]
grep -q 'Recuperação manual' "$sandbox/output"
[ ! -d "$state/lock" ]
# Retry completes the operation while keeping recovery artifacts.
yes_cli link
cli status > /dev/null
cmp "$HOME/.zshrc" "$sandbox/startup"
echo 'ok - partial failure, preserved backup, successful retry'
yes_cli unlink
rmdir "${dest%/*}"
mkdir "$HOME/elsewhere"
ln -s "$HOME/elsewhere" "${dest%/*}"
fail_cli link
[ ! -e "$HOME/elsewhere/zshrc" ]
echo 'ok - symlink ancestor rejected'
