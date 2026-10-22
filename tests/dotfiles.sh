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
# Failure preparing the candidate must leave the approved original in place.
cp "$CW_DOTFILES_REPO/manifests/terminal/zshrc" "$dest"
mkdir "$sandbox/mock"
printf '#!/bin/bash\nexit 71\n' > "$sandbox/mock/ln"
chmod +x "$sandbox/mock/ln"
if printf 's\n' | PATH="$sandbox/mock:$PATH" cli link > "$sandbox/output"; then exit 1; fi
[ -f "$dest" ] && [ ! -L "$dest" ]
cmp "$dest" "$CW_DOTFILES_REPO/manifests/terminal/zshrc"
grep -q 'Recuperação manual' "$sandbox/output"
[ ! -d "$state/lock" ]
# Retry completes the operation while keeping recovery artifacts.
yes_cli link
cli status > /dev/null
cmp "$HOME/.zshrc" "$sandbox/startup"
echo 'ok - preparation failure preserves original, backup and retry'
yes_cli unlink
cp "$CW_DOTFILES_REPO/manifests/terminal/zshrc" "$dest"
# Fail only the actual replacement, allowing capability probes.
cat > "$sandbox/mock/mv" <<'MOCK'
#!/bin/bash
case "$2" in */link) exit 72 ;; esac
exec /bin/mv "$@"
MOCK
chmod +x "$sandbox/mock/mv"
rm "$sandbox/mock/ln"
if printf 's\n' | PATH="$sandbox/mock:$PATH" cli link > "$sandbox/output"; then exit 1; fi
cmp "$dest" "$CW_DOTFILES_REPO/manifests/terminal/zshrc"
[ ! -L "$dest" ] && [ ! -d "$state/lock" ]
echo 'ok - replacement failure preserves original'
# Unsupported rename semantics must fail closed, not fall back to rm + ln.
printf '#!/bin/bash\nexit 74\n' > "$sandbox/mock/mv"
if printf 's\n' | PATH="$sandbox/mock:$PATH" cli link > "$sandbox/output"; then exit 1; fi
[ ! -L "$dest" ]
cmp "$dest" "$CW_DOTFILES_REPO/manifests/terminal/zshrc"
grep -q 'original preservado' "$sandbox/output"
echo 'ok - unsupported replacement refuses conversion'
# Restore real rename so the concurrency test reaches the final validation.
printf '#!/bin/bash\nexec /bin/mv "$@"\n' > "$sandbox/mock/mv"
# Mutate after backup/preparation, before final validation.
cat > "$sandbox/mock/ln" <<'MOCK'
#!/bin/bash
/bin/ln "$@" || exit $?
case "$3" in */link) printf concurrent > "$TEST_DEST" ;; esac
MOCK
chmod +x "$sandbox/mock/ln"
if printf 's\n' | TEST_DEST="$dest" PATH="$sandbox/mock:$PATH" cli link > "$sandbox/output"; then exit 1; fi
[ "$(cat "$dest")" = concurrent ]
grep -q 'mudou durante operação' "$sandbox/output"
rm "$sandbox/mock/ln" "$sandbox/mock/mv"
echo 'ok - concurrent write after preparation is preserved'
# Change inode with identical bytes during confirmation (not just checksum).
(
    CW_ROOT=$root
    . "$root/lib/setup.sh"
    . "$root/lib/dotfiles.sh"
    cp "$CW_DOTFILES_REPO/manifests/terminal/zshrc" "$dest"
    cw_confirm() { cp "$dest" "$dest.new"; mv "$dest.new" "$dest"; }
    if cw_dotfiles link > "$sandbox/output"; then exit 1; fi
    [ ! -L "$dest" ]
)
echo 'ok - same-byte concurrent replacement during confirmation detected'
# A handled signal during staging keeps the original and records recovery state.
cat > "$sandbox/mock/ln" <<'MOCK'
#!/bin/bash
kill -TERM "$PPID"
exit 73
MOCK
chmod +x "$sandbox/mock/ln"
if printf 's\n' | PATH="$sandbox/mock:$PATH" cli link > "$sandbox/output"; then exit 1; fi
[ -f "$dest" ] && [ ! -L "$dest" ] && [ ! -d "$state/lock" ]
cmp "$dest" "$CW_DOTFILES_REPO/manifests/terminal/zshrc"
grep -q 'Recuperação manual' "$sandbox/output"
rm "$sandbox/mock/ln"
echo 'ok - TERM preserves original and journal, releases lock'
# Relative links remain foreign even if they resolve to the approved file.
rm "$dest"
ln -s "../../../repository/manifests/terminal/zshrc" "$dest"
fail_cli link; fail_cli unlink
rm "$dest"
# Residual locks block mutations; journals remain available without auto-deletion.
mkdir "$state/lock"
fail_cli link
rmdir "$state/lock"
yes_cli link
yes_cli unlink
# Failed staging artifacts are deliberately retained for manual recovery.
for work in "${dest%/*}"/.cw-dotfiles.*; do
    [ -d "$work" ] || continue
    rm -rf "$work"
done
rmdir "${dest%/*}"
mkdir "$HOME/elsewhere"
ln -s "$HOME/elsewhere" "${dest%/*}"
fail_cli link
[ ! -e "$HOME/elsewhere/zshrc" ]
echo 'ok - symlink ancestor rejected'
