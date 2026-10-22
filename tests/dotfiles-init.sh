#!/bin/bash
# All mutations stay inside this disposable fixture. No network or personal HOME.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
sandbox=$(mktemp -d "$root/tests/.phase5.XXXXXX")
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox/home with spaces"
unset XDG_DATA_HOME XDG_STATE_HOME XDG_CONFIG_HOME CW_DOTFILES_REPO GIT_DIR GIT_WORK_TREE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME" "$sandbox/source" "$sandbox/mock"
cp -R "$root/bin" "$root/lib" "$root/manifests" "$root/modules" "$root/platforms" "$root/install.sh" "$sandbox/source/"
export CW_TEST_LOG="$sandbox/git-log"
export CW_TEST_REAL_GIT=$(command -v git)
# A local object store supplies exactly the audited reference; URL remains approved.
"$CW_TEST_REAL_GIT" clone --quiet --no-hardlinks "$root" "$sandbox/upstream"
export CW_TEST_UPSTREAM="$sandbox/upstream"
cat > "$sandbox/mock/git" <<'MOCK'
#!/bin/bash
set -eu
printf '%s\n' "$*" >> "$CW_TEST_LOG"
case "$*" in
    *' clone '*)
        [ "${CW_TEST_FAIL:-}" != clone ] || exit 72
        for last; do :; done
        "$CW_TEST_REAL_GIT" clone --quiet --no-checkout --no-hardlinks "$CW_TEST_UPSTREAM" "$last"
        "$CW_TEST_REAL_GIT" -C "$last" remote set-url origin https://github.com/gabriel-vitebo/dotfile.git
        printf '#!/bin/bash\ntouch "$HOME/pwned"\n' > "$last/.git/hooks/post-checkout"
        chmod +x "$last/.git/hooks/post-checkout"
        if [ "${CW_TEST_FAIL:-}" = signal ]; then kill -TERM "$PPID"; exit 143; fi
        exit 0 ;;
    *' checkout '*)
        "$CW_TEST_REAL_GIT" "$@"
        if [ "${CW_TEST_FAIL:-}" = validation ]; then
            previous=
            for arg; do
                if [ "$previous" = -C ]; then rm "$arg/manifests/git.config"; break; fi
                previous=$arg
            done
        fi
        exit 0 ;;
esac
exec "$CW_TEST_REAL_GIT" "$@"
MOCK
# env -i is part of the production security boundary. The mock env only adds
# fixture variables back, then calls real env; Git config isolation is retained.
export CW_TEST_REAL_ENV=$(command -v env)
cat > "$sandbox/mock/env" <<'MOCK'
#!/bin/bash
set -eu
if [ "${1:-}" = -i ]; then
    shift
    exec "$CW_TEST_REAL_ENV" -i CW_TEST_REAL_GIT="$CW_TEST_REAL_GIT" CW_TEST_LOG="$CW_TEST_LOG" \
        CW_TEST_UPSTREAM="$CW_TEST_UPSTREAM" CW_TEST_FAIL="${CW_TEST_FAIL:-}" "$@"
fi
exec "$CW_TEST_REAL_ENV" "$@"
MOCK
chmod +x "$sandbox/mock/git" "$sandbox/mock/env"
export PATH="$sandbox/mock:$PATH"
repo="$HOME/.local/share/config-workplace-dotfiles/repository"
state="$HOME/.local/state/config-workplace/dotfiles"
checks=0
pass() { checks=$((checks + 1)); printf 'ok %s - %s\n' "$checks" "$*"; }
cli() { /bin/bash "$sandbox/source/bin/workspace" dotfiles "$@"; }
yes_cli() { printf 's\n' | cli "$@" > "$sandbox/output" 2>&1; }
fail_cli() { if cli "$@" </dev/null > "$sandbox/output" 2>&1; then cat "$sandbox/output"; exit 1; fi; }
snapshot() { find "$HOME" -print; find "$HOME" -type f -exec cksum {} \;; }
# Simulate supported OS variants without pretending to execute GNU tools on BSD.
(
    CW_ROOT="$sandbox/source"; . "$CW_ROOT/lib/setup.sh"; . "$CW_ROOT/lib/dotfiles.sh"
    cw_is_ubuntu() { return 0; }
    uname() { case "$1" in -s) printf Linux ;; -m) printf x86_64 ;; esac; }
    cw_platform >/dev/null; [ "$cw_os" = ubuntu ]
    uname() { case "$1" in -s) printf Darwin ;; -m) printf arm64 ;; esac; }
    cw_platform >/dev/null; [ "$cw_os" = macos ]
    cw_df_temporary /private/tmp/checkout
    cw_df_temporary /tmp/checkout
    cw_df_temporary /private/var/folders/test/checkout
)
pass 'macOS/Ubuntu platform contracts and temporary path detection'
printf 'personal startup\n' > "$HOME/.zshrc"
printf '[user]\n name = Personal\n' > "$HOME/.gitconfig"
cp "$HOME/.gitconfig" "$sandbox/personal"
snapshot > "$sandbox/before"
cli init --dry-run > "$sandbox/output"
cli init </dev/null >> "$sandbox/output"
snapshot > "$sandbox/after"; cmp "$sandbox/before" "$sandbox/after"
[ ! -e "$CW_TEST_LOG" ]
pass 'clean dry-run and refusal: no Git, directories, state or personal changes'
yes_cli init
[ -d "$repo/.git" ] && [ ! -e "$HOME/.config/config-workplace-terminal/zshrc" ]
[ ! -e "$HOME/pwned" ] && [ ! -e "$HOME/.local/bin/workspace" ]
[ "$("$CW_TEST_REAL_GIT" -C "$repo" rev-parse HEAD)" = e0ebd0226328b9a4551bd344fa8bb1bcc6126401 ]
cmp "$HOME/.gitconfig" "$sandbox/personal"
grep -q 'complete' "$state"/operation.*/journal
pass 'clean machine: approved clone pinned, no automatic links or personal changes'
clones=$(grep -c ' clone ' "$CW_TEST_LOG")
snapshot > "$sandbox/before"
cli init </dev/null > "$sandbox/output"
cli init --dry-run > "$sandbox/output"
snapshot > "$sandbox/after"; cmp "$sandbox/before" "$sandbox/after"
[ "$clones" = "$(grep -c ' clone ' "$CW_TEST_LOG")" ]
pass 'existing checkout reused and repeated init is inert'
fail_cli doctor
grep -q absent "$sandbox/output"
yes_cli link --all
cli doctor > "$sandbox/output"
pass 'doctor distinguishes prepared checkout from linked configurations'
snapshot > "$sandbox/before"; cli doctor > "$sandbox/output"
snapshot > "$sandbox/after"; cmp "$sandbox/before" "$sandbox/after"
pass 'healthy doctor is read-only'
mv "$repo/manifests/terminal/zshrc" "$sandbox/zshrc"
fail_cli doctor
grep -q broken-managed "$sandbox/output"
mv "$sandbox/zshrc" "$repo/manifests/terminal/zshrc"
mkdir "$state/operation.interrupted"
printf 'prepared\n' > "$state/operation.interrupted/journal"
mkdir "$state/lock"
fail_cli doctor
grep -q 'Journal incompleto' "$sandbox/output"; grep -q 'Lock ativo ou residual' "$sandbox/output"
[ -d "$state/lock" ]; fail_cli init
rm -r "$state/operation.interrupted"; rmdir "$state/lock"
pass 'broken links, incomplete journals and residual locks diagnosed without repair'
printf 'changed\n' >> "$repo/manifests/git.config"
cp "$repo/manifests/git.config" "$sandbox/changed"
fail_cli init; fail_cli doctor
cmp "$repo/manifests/git.config" "$sandbox/changed"
"$CW_TEST_REAL_GIT" -C "$repo" show HEAD:manifests/git.config > "$repo/manifests/git.config"
pass 'validation failure preserves local changes'
for kind in file directory symlink; do
    occupied="$HOME/occupied-$kind"
    case "$kind" in file) printf keep > "$occupied" ;; directory) mkdir "$occupied" ;; symlink) ln -s "$repo" "$occupied" ;; esac
    CW_DOTFILES_REPO="$occupied" fail_cli init
    [ -e "$occupied" ] || [ -L "$occupied" ]
done
pass 'occupied files, empty unknown directories and symlinks refused'
for kind in clone validation signal; do
    target="$HOME/failure-$kind"
    if printf 's\n' | CW_TEST_FAIL="$kind" CW_DOTFILES_REPO="$target" cli init > "$sandbox/output" 2>&1; then cat "$sandbox/output"; exit 1; fi
    [ -d "$target" ]; [ ! -d "$state/lock" ]
    grep -q incomplete "$state"/operation.*/journal
    fail_cli doctor
    # Fixture cleanup only: the production command never removes failed clones.
    for journal in "$state"/operation.*/journal; do
        if [ "$(tail -n 1 "$journal")" != complete ]; then rm -r "${journal%/*}"; fi
    done
done
pass 'clone/validation failures and TERM retain artifacts and incomplete journals'
(
    CW_ROOT="$sandbox/source"; . "$CW_ROOT/lib/setup.sh"; . "$CW_ROOT/lib/dotfiles.sh"
    export CW_DOTFILES_REPO="$HOME/concurrent"
    cw_confirm() { mkdir "$CW_DOTFILES_REPO"; printf keep > "$CW_DOTFILES_REPO/personal"; }
    if cw_dotfiles init > "$sandbox/output"; then exit 1; fi
    [ "$(cat "$CW_DOTFILES_REPO/personal")" = keep ]
)
pass 'destination introduced during confirmation is preserved'
CW_DOTFILES_REPO="$sandbox/source/nested" fail_cli init
CW_DOTFILES_REPO=/private/tmp/dotfiles-forbidden fail_cli init
fail_cli init --all; fail_cli doctor --dry-run
pass 'temporary/CLI paths and unsupported arguments refused'
touch "$repo/.git/index.lock"
fail_cli doctor; rm "$repo/.git/index.lock"
printf '/tmp/objects\n' > "$repo/.git/objects/info/alternates"
fail_cli init; rm "$repo/.git/objects/info/alternates"
"$CW_TEST_REAL_GIT" -C "$repo" remote set-url origin https://example.invalid/third-party.git
fail_cli init
"$CW_TEST_REAL_GIT" -C "$repo" remote set-url origin https://github.com/gabriel-vitebo/dotfile.git
"$CW_TEST_REAL_GIT" -C "$repo" config remote.origin.promisor true
fail_cli doctor; grep -q 'Clone parcial' "$sandbox/output"
"$CW_TEST_REAL_GIT" -C "$repo" config --unset remote.origin.promisor
pass 'Git locks, shared/remote objects and unauthorized upstream refused'
mkdir "$state/operation.no-journal"
fail_cli doctor; grep -q 'sem journal' "$sandbox/output"
rmdir "$state/operation.no-journal"
chmod 755 "$state"
fail_cli doctor; grep -q 'acessíveis' "$sandbox/output"
chmod 700 "$state"
pass 'missing journals and exposed backup directory are reported, never repaired'
(
    CW_ROOT="$sandbox/source"; . "$CW_ROOT/lib/setup.sh"; . "$CW_ROOT/lib/dotfiles.sh"
    cw_is_ubuntu() { return 0; }
    uname() { case "$1" in -s) printf Linux ;; -m) printf x86_64 ;; esac; }
    cw_dotfiles init --dry-run > "$sandbox/output"
    cw_dotfiles doctor > "$sandbox/output"
    uname() { case "$1" in -s) printf Darwin ;; -m) printf arm64 ;; esac; }
    cw_dotfiles init --dry-run > "$sandbox/output"
    cw_dotfiles doctor > "$sandbox/output"
    uname() { printf Unsupported; }
    if cw_dotfiles init --dry-run > "$sandbox/output"; then exit 1; fi
)
pass 'init/doctor work with macOS and Ubuntu detection mocks; unsupported OS blocked'
PATH="$HOME/.local/bin:$PATH" /bin/bash "$sandbox/source/install.sh" </dev/null > "$sandbox/output"
rm -rf "$sandbox/source" "$sandbox/upstream"
"$HOME/.local/bin/workspace" dotfiles doctor > "$sandbox/output"
"$HOME/.local/bin/workspace" dotfiles init </dev/null > "$sandbox/output"
[ "$(readlink "$HOME/.config/config-workplace-terminal/zshrc")" = "$repo/manifests/terminal/zshrc" ]
[ "$(GIT_CONFIG_GLOBAL="$HOME/.gitconfig" "$CW_TEST_REAL_GIT" config --global --includes user.name)" = Personal ]
pass 'installed CLI, independent objects and managed links survive initial clone deletion'
printf '\n%s verificações concluídas.\n' "$checks"
