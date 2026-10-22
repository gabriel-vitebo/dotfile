#!/bin/bash
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
sandbox=$(mktemp -d)
sandbox=$(cd "$sandbox" && pwd -P)
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox/home with spaces"
export CW_DOTFILES_REPO="$sandbox/permanent repo"
unset XDG_STATE_HOME XDG_DATA_HOME XDG_CONFIG_HOME ZDOTDIR
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
mkdir -p "$HOME" "$CW_DOTFILES_REPO/manifests/terminal" "$sandbox/mock"
cp "$root/manifests/terminal/zshrc" "$CW_DOTFILES_REPO/manifests/terminal/"
cp "$root/manifests/git.config" "$CW_DOTFILES_REPO/manifests/"
terminal="$HOME/.config/config-workplace-terminal/zshrc"
state="$HOME/.local/state/config-workplace/dotfiles"
checks=0
pass() { checks=$((checks + 1)); printf 'ok %s - %s\n' "$checks" "$*"; }
cli() { /bin/bash "$root/bin/workspace" dotfiles "$@"; }
yes_cli() { printf 's\n' | cli "$@" > "$sandbox/output"; }
fail_cli() { if cli "$@" </dev/null > "$sandbox/output"; then cat "$sandbox/output"; exit 1; fi; }
cli list > "$sandbox/list"
[ "$(wc -l < "$sandbox/list" | tr -d ' ')" = 3 ]
grep -q '^terminal |' "$sandbox/list"; grep -q '^git |' "$sandbox/list"; grep -q '^vscode |' "$sandbox/list"
cli list --only git | grep -q 'git-include'
fail_cli link --only unknown
fail_cli link --all --only git
fail_cli link --only
fail_cli link --force
pass 'manifest listing and strict option selection'
printf '# personal\n[user]\n name = Personal Name\n email = personal@example.invalid\n[diff]\n algorithm = patience\n[alias]\n st = status --branch' > "$HOME/.gitconfig"
chmod 640 "$HOME/.gitconfig"
cp -p "$HOME/.gitconfig" "$sandbox/personal-git"
printf 'ZSH_THEME=custom\nalias personal=true\n' > "$HOME/.zshrc"
cp "$HOME/.zshrc" "$sandbox/personal-zsh"
cli link --all --dry-run > "$sandbox/output"
[ ! -e "$state" ] && [ ! -e "$terminal" ]
cmp "$HOME/.gitconfig" "$sandbox/personal-git"
pass 'all dry-run creates no state, destination or backup'
yes_cli link --only git
[ ! -L "$HOME/.gitconfig" ] && [ ! -e "$terminal" ]
[ "$(git config --global --includes user.name)" = 'Personal Name' ]
[ "$(git config --global --includes user.email)" = personal@example.invalid ]
[ "$(git config --global --includes diff.algorithm)" = patience ]
[ "$(git config --global --includes alias.st)" = 'status --branch' ]
[ "$(git config --global --includes alias.co)" = checkout ]
[ "$(LC_ALL=C ls -l "$HOME/.gitconfig" | cut -c1-10)" = '-rw-r-----' ]
pass 'Git include preserves identity, permissions and personal precedence'
cli status --only git >/dev/null
count=$(find "$state" -print | wc -l)
cli link --only git </dev/null >/dev/null
[ "$count" = "$(find "$state" -print | wc -l)" ]
found=0
for backup in "$state"/operation.*/original; do
    [ -f "$backup" ] || continue
    cmp "$backup" "$sandbox/personal-git"
    found=1
done
[ "$found" = 1 ]
pass 'idempotent Git, backup bytes and journal'
yes_cli unlink --only git
cmp "$HOME/.gitconfig" "$sandbox/personal-git"
[ ! -e "$terminal" ]
cli unlink --only git </dev/null >/dev/null
cmp "$HOME/.gitconfig" "$sandbox/personal-git"
pass 'Git unlink restores exact personal bytes without trailing newline; repeat is inert'
# An edited/repositioned managed marker is a conflict, never rewritten.
printf '\n# BEGIN config-workplace portable Git\n' >> "$HOME/.gitconfig"
cp "$HOME/.gitconfig" "$sandbox/conflict"
fail_cli link --all
[ ! -e "$terminal" ]; cmp "$HOME/.gitconfig" "$sandbox/conflict"
fail_cli unlink --only git
cp "$sandbox/personal-git" "$HOME/.gitconfig"
pass 'whole selection preflight blocks before any writes'
mv "$CW_DOTFILES_REPO/manifests/git.config" "$sandbox/git-source"
fail_cli link --all
[ ! -e "$terminal" ]
mv "$sandbox/git-source" "$CW_DOTFILES_REPO/manifests/git.config"
pass 'missing source blocks entire selection'
# JSONC remains byte-for-byte unchanged; CLI must never invoke Node.
printf '#!/bin/bash\nexit 91\n' > "$sandbox/mock/node"
chmod +x "$sandbox/mock/node"
for os in macos ubuntu; do
    (
        CW_ROOT=$root; . "$root/lib/setup.sh"; . "$root/lib/dotfiles.sh"
        cw_os=$os; destination=$(cw_df_destination vscode)
        case "$os" in
            macos) [ "$destination" = "$HOME/Library/Application Support/Code/User/settings.json" ] ;;
            ubuntu) [ "$destination" = "$HOME/.config/Code/User/settings.json" ] ;;
        esac
        mkdir -p "${destination%/*}"
        printf '// JSONC\n{"editor.fontSize":19,"unknown.machine":true,}\n' > "$destination"
        cp "$destination" "$sandbox/jsonc-$os"
        PATH="$sandbox/mock:$PATH" cw_dotfiles link --only vscode > "$sandbox/output"
        cmp "$destination" "$sandbox/jsonc-$os"
        rm "$destination"
        ln -s "$sandbox/jsonc-$os" "$destination"
        if cw_dotfiles link --only vscode > "$sandbox/output"; then exit 1; fi
        cmp "$destination" "$sandbox/jsonc-$os"
        rm "$destination"
    )
done
pass 'VS Code platform paths, JSONC preservation, no Node and external link rejection'
yes_cli link --all
[ -L "$terminal" ]; cli status --all >/dev/null
cmp "$HOME/.zshrc" "$sandbox/personal-zsh"
[ "$(git config --global --includes alias.co)" = checkout ]
pass 'all selected entries, personal terminal theme intact'
# Fail only Git publication, after terminal has succeeded. No rollback deletions.
yes_cli unlink --all
cat > "$sandbox/mock/mv" <<'MOCK'
#!/bin/bash
case "$2" in */config) exit 72 ;; esac
exec /bin/mv "$@"
MOCK
chmod +x "$sandbox/mock/mv"
if printf 's\n' | PATH="$sandbox/mock:$PATH" cli link --all > "$sandbox/output"; then exit 1; fi
[ -L "$terminal" ]; cmp "$HOME/.gitconfig" "$sandbox/personal-git"
[ ! -d "$state/lock" ]
grep -q 'Recuperação manual' "$sandbox/output"
rm "$sandbox/mock/mv"
yes_cli link --all
pass 'partial failure retains prior success, original Git, journal and retry'
mv "$CW_DOTFILES_REPO/manifests/git.config" "$sandbox/git-source"
fail_cli status --only git
yes_cli unlink --only git
cmp "$HOME/.gitconfig" "$sandbox/personal-git"
mv "$sandbox/git-source" "$CW_DOTFILES_REPO/manifests/git.config"
pass 'broken include can be removed without losing personal configuration'
# Edits made after applying the include survive unlink, rather than restoring a stale backup.
yes_cli link --only git
printf '\n# later personal edit\n' >> "$HOME/.gitconfig"
yes_cli unlink --only git
grep -q 'later personal edit' "$HOME/.gitconfig"
cp "$sandbox/personal-git" "$HOME/.gitconfig"
pass 'unlink preserves personal edits made after link'
# Revalidate all files after confirmation before creating the first link.
yes_cli unlink --only terminal
(
    CW_ROOT=$root; . "$root/lib/setup.sh"; . "$root/lib/dotfiles.sh"
    cw_confirm() { printf '\n# concurrent edit\n' >> "$HOME/.gitconfig"; }
    if cw_dotfiles link --all > "$sandbox/output"; then exit 1; fi
    [ ! -e "$terminal" ]
    grep -q 'concurrent edit' "$HOME/.gitconfig"
)
cp "$sandbox/personal-git" "$HOME/.gitconfig"
pass 'concurrent Git edit during approval blocks all writes'
mv "$HOME/.gitconfig" "$sandbox/config-away"
ln -s "$sandbox/config-away" "$HOME/.gitconfig"
fail_cli link --only git
fail_cli unlink --only git
cmp "$sandbox/config-away" "$sandbox/personal-git"
rm "$HOME/.gitconfig"
yes_cli link --only git
[ "$(git config --global --includes alias.co)" = checkout ]
yes_cli unlink --only git
[ ! -s "$HOME/.gitconfig" ]
mv "$sandbox/config-away" "$HOME/.gitconfig"
pass 'foreign Git symlink refused; missing Git config created and unlinked safely'
# Isolated CLI copy: modified manifest must not execute shell or redirect writes.
mkdir "$sandbox/source"
cp -R "$root/bin" "$root/lib" "$root/modules" "$root/platforms" "$root/manifests" "$root/install.sh" "$sandbox/source/"
cp "$sandbox/source/manifests/dotfiles.manifest" "$sandbox/manifest"
for malicious in 'git|../../outside|git|macos,ubuntu|git-include|bad' 'git|manifests/git.config|/tmp/escape|macos,ubuntu|git-include|bad' '$(touch "$HOME/pwned")|x|x|x|x|bad'; do
    printf '%s\n' "$malicious" >> "$sandbox/source/manifests/dotfiles.manifest"
    if /bin/bash "$sandbox/source/bin/workspace" dotfiles link --all --dry-run > "$sandbox/output"; then exit 1; fi
    [ ! -e "$HOME/pwned" ]
    cp "$sandbox/manifest" "$sandbox/source/manifests/dotfiles.manifest"
done
pass 'manifest duplicate, traversal, destination and command injection rejected'
# Real fixture bootstrap; delete source, keep explicit permanent repository.
PATH="$HOME/.local/bin:$PATH" /bin/bash "$sandbox/source/install.sh" </dev/null > "$sandbox/output"
rm -rf "$sandbox/source"
printf 's\n' | "$HOME/.local/bin/workspace" dotfiles link --all > "$sandbox/output"
"$HOME/.local/bin/workspace" dotfiles status --all > "$sandbox/output"
[ "$(readlink "$terminal")" = "$CW_DOTFILES_REPO/manifests/terminal/zshrc" ]
[ "$(git config --global --includes alias.co)" = checkout ]
cmp "$HOME/.zshrc" "$sandbox/personal-zsh"
pass 'installed CLI and active Git/terminal survive deletion of original clone'
printf '\n%s verificações concluídas.\n' "$checks"
