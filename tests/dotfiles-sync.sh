#!/bin/bash
# Real local Git objects/remotes; mock transport refuses every other URL.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
sandbox=$(mktemp -d "$root/tests/.phase6.XXXXXX")
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox/home with spaces"
unset XDG_DATA_HOME XDG_STATE_HOME XDG_CONFIG_HOME CW_DOTFILES_REPO GIT_DIR GIT_WORK_TREE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export CW_TEST_REAL_GIT=$(command -v git) CW_TEST_REAL_ENV=$(command -v env)
export CW_TEST_REMOTE="$sandbox/remote.git" CW_TEST_LOG="$sandbox/transport"
mkdir -p "$HOME" "$sandbox/source" "$sandbox/mock"
cp -R "$root/bin" "$root/lib" "$root/manifests" "$root/modules" "$root/platforms" "$root/install.sh" "$sandbox/source/"
git clone --quiet --no-hardlinks "$root" "$sandbox/seed"
git -C "$sandbox/seed" checkout -q -B main e0ebd0226328b9a4551bd344fa8bb1bcc6126401
git -C "$sandbox/seed" config user.name Fixture
git -C "$sandbox/seed" config user.email fixture@example.test
git clone --quiet --bare "$sandbox/seed" "$CW_TEST_REMOTE"
cat > "$sandbox/mock/git" <<'MOCK'
#!/bin/bash
set -eu
args=(); i=0; transport=0
for arg; do
    case "$arg" in fetch|push) transport=1; operation=$arg ;; esac
    if [ "$arg" = https://github.com/gabriel-vitebo/dotfile.git ]; then
        arg=$CW_TEST_REMOTE
    elif [[ "$arg" == *://* ]]; then exit 90; fi
    args[$i]=$arg; i=$((i + 1))
done
if [ "$transport" -eq 1 ]; then
    printf '%s\n' "$operation" >> "$CW_TEST_LOG"
    case "${CW_TEST_FAIL:-}" in network) exit 71 ;; auth) printf 'token=DO_NOT_PRINT\n' >&2; exit 72 ;; push) [ "$operation" != push ] || exit 73 ;; esac
fi
exec "$CW_TEST_REAL_GIT" -c protocol.file.allow=always "${args[@]}"
MOCK
cat > "$sandbox/mock/env" <<'MOCK'
#!/bin/bash
set -eu
if [ "${1:-}" = -i ]; then
    shift
    exec "$CW_TEST_REAL_ENV" -i CW_TEST_REAL_GIT="$CW_TEST_REAL_GIT" CW_TEST_REMOTE="$CW_TEST_REMOTE" \
        CW_TEST_LOG="$CW_TEST_LOG" CW_TEST_FAIL="${CW_TEST_FAIL:-}" "$@"
fi
exec "$CW_TEST_REAL_ENV" "$@"
MOCK
chmod +x "$sandbox/mock/git" "$sandbox/mock/env"
export PATH="$sandbox/mock:$PATH"
repo="$HOME/.local/share/config-workplace-dotfiles/repository"
state="$HOME/.local/state/config-workplace/dotfiles"
checks=0
pass() { checks=$((checks + 1)); printf 'ok %s - %s\n' "$checks" "$*"; }
cli() { /bin/bash "$sandbox/source/bin/workspace" dotfiles sync "$@"; }
run() { printf '%b' "$1" | cli > "$sandbox/output" 2>&1; }
fail() { if cli "$@" </dev/null > "$sandbox/output" 2>&1; then cat "$sandbox/output"; exit 1; fi; }
g() { "$CW_TEST_REAL_GIT" -C "$repo" "$@"; }
seed() { "$CW_TEST_REAL_GIT" -C "$sandbox/seed" "$@"; }
reset_fixture() {
    rm -rf "$repo" "$state"
    mkdir -p "${repo%/*}"
    "$CW_TEST_REAL_GIT" clone --quiet --no-hardlinks "$CW_TEST_REMOTE" "$repo"
    g remote set-url origin https://github.com/gabriel-vitebo/dotfile.git
    g config user.name Fixture; g config user.email fixture@example.test
}
snapshot() { find "$HOME" -type f -exec cksum {} \; | LC_ALL=C sort; }
reset_fixture
printf 'personal zsh\n' > "$HOME/.zshrc"
printf '[user]\nname = Personal\n' > "$HOME/.gitconfig"
cp "$HOME/.zshrc" "$sandbox/zsh.before"; cp "$HOME/.gitconfig" "$sandbox/git.before"
snapshot > "$sandbox/before"
cli --status > "$sandbox/output"; grep -q SKIP "$sandbox/output"
cli --dry-run > "$sandbox/output"; cli </dev/null > "$sandbox/output"
snapshot > "$sandbox/after"; cmp "$sandbox/before" "$sandbox/after"
pass 'clean/status/dry-run/reexecution preserve every permanent file'
printf '\n# portable preference\n' >> "$repo/manifests/git.config"
snapshot > "$sandbox/before"
cli --dry-run > "$sandbox/output"; grep -q '+# portable preference' "$sandbox/output"
run 'n\n'; grep -q recusada "$sandbox/output"
snapshot > "$sandbox/after"; cmp "$sandbox/before" "$sandbox/after"
pass 'local diff and refusal preserve working tree/index/refs'
old=$(g rev-parse HEAD)
run 's\nn\n'
[ "$(g rev-parse HEAD)" != "$old" ]; [ "$(git --git-dir="$CW_TEST_REMOTE" rev-parse main)" = "$old" ]
[ -z "$(g status --porcelain)" ]; grep -q 'Push recusado' "$sandbox/output"
pass 'commit approval and separate push refusal retain unpublished commit'
run 's\n'
[ "$(g rev-parse HEAD)" = "$(git --git-dir="$CW_TEST_REMOTE" rev-parse main)" ]
cli --status > "$sandbox/output"; grep -q SKIP "$sandbox/output"
pass 'explicit push and idempotent retry use local bare remote only'
# Prepare remote-only changes on a peer, preserving published local commit.
seed fetch -q "$CW_TEST_REMOTE" main
seed merge --ff-only -q FETCH_HEAD
printf '\n# remote preference\n' >> "$sandbox/seed/manifests/git.config"
seed commit -qam 'portable remote preference'
seed push -q "$CW_TEST_REMOTE" main
old=$(g rev-parse HEAD)
snapshot > "$sandbox/before"
cli --dry-run > "$sandbox/output"; grep -q '+# remote preference' "$sandbox/output"
run 'n\n'; snapshot > "$sandbox/after"; cmp "$sandbox/before" "$sandbox/after"
run 's\n'; [ "$(g rev-parse HEAD)" != "$old" ]; [ -z "$(g status --porcelain)" ]
[ -f "$state"/operation.*/index.before ] 2>/dev/null || test -n "$(find "$state" -name index.before -print)"
pass 'remote preview/refusal/approved fast-forward with backups'
reset_fixture
printf '\n# local only\n' >> "$repo/manifests/git.config"
printf '\n# peer only\n' >> "$sandbox/seed/manifests/git.config"
seed commit -qam 'peer preference'; seed push -q "$CW_TEST_REMOTE" main
fail; grep -q 'Alterações locais e remotas' "$sandbox/output"
g add manifests/git.config; g commit -qm 'local preference'
fail; grep -q 'divergência' "$sandbox/output"
[ ! -f "$repo/.git/MERGE_HEAD" ]
pass 'dirty plus remote and branch divergence never merge'
# Actual unmerged index, deliberately introduced only inside test fixture.
g fetch -q "$CW_TEST_REMOTE" main
if g -c core.hooksPath=/dev/null merge --no-edit FETCH_HEAD > "$sandbox/merge" 2>&1; then exit 1; fi
fail; grep -q 'operação Git pendente' "$sandbox/output"
pass 'existing merge conflict is preserved'
reset_fixture
printf 'private\n' > "$repo/unknown.txt"
fail --dry-run; grep -q allowlist "$sandbox/output"
rm "$repo/unknown.txt"
printf '\npassword = DO_NOT_PRINT\n' >> "$repo/manifests/git.config"
fail; grep -q suspeito "$sandbox/output"; ! grep -q DO_NOT_PRINT "$sandbox/output"
pass 'unapproved files and possible secret block before content display'
reset_fixture
printf '\n# approved\n' >> "$repo/manifests/git.config"
g add manifests/git.config
fail; grep -q 'Índice já contém' "$sandbox/output"
pass 'preexisting staging is preserved'
reset_fixture
for fault in network auth; do
    snapshot > "$sandbox/before"
    CW_TEST_FAIL=$fault fail --status
    ! grep -q DO_NOT_PRINT "$sandbox/output"
    snapshot > "$sandbox/after"; cmp "$sandbox/before" "$sandbox/after"
done
pass 'network/auth failures preserve checkout and redact raw transport errors'
printf '\n# publish later\n' >> "$repo/manifests/git.config"
if printf 's\ns\n' | CW_TEST_FAIL=push cli > "$sandbox/output" 2>&1; then exit 1; fi
[ -z "$(g status --porcelain)" ]; grep -q incomplete "$state"/operation.*/journal
fail; grep -q 'Journal incompleto' "$sandbox/output"
pass 'failed push preserves commit and incomplete recovery journal'
reset_fixture
g checkout -q --detach
fail; grep -q 'branch main' "$sandbox/output"
g checkout -q main
g config alias.evil '!touch "$HOME/pwned"'
fail; [ ! -e "$HOME/pwned" ]
g config --unset alias.evil
printf '#!/bin/sh\ntouch "$HOME/pwned"\n' > "$repo/.git/hooks/pre-commit"
chmod +x "$repo/.git/hooks/pre-commit"
printf '\n# no hook\n' >> "$repo/manifests/git.config"
run 's\nn\n'; [ ! -e "$HOME/pwned" ]
pass 'detached/config injection rejected and unknown hooks disabled'
reset_fixture
printf 'not portable\n' > "$repo/unknown.txt"
g add unknown.txt; g commit -qm 'mixed history'
g rm -q unknown.txt; g commit -qm 'remove unknown'
fail --status; grep -q allowlist "$sandbox/output"
pass 'unapproved intermediate files block even when final tree matches'
reset_fixture
ln "$repo/manifests/git.config" "$sandbox/hardlink"
fail; grep -q hardlinks "$sandbox/output"
rm "$sandbox/hardlink"
printf '* filter=unknown\n' > "$repo/.gitattributes"
fail; grep -q Atributos "$sandbox/output"
rm "$repo/.gitattributes"
g update-index --assume-unchanged manifests/git.config
fail; grep -q assume-unchanged "$sandbox/output"
g update-index --no-assume-unchanged manifests/git.config
g config core.fsmonitor 'touch "$HOME/pwned"'
fail; [ ! -e "$HOME/pwned" ]
g config --unset core.fsmonitor
pass 'hardlinks, attributes, hidden index changes and executable Git config rejected'
reset_fixture
# A secret later reverted remains in the outgoing history and must block push.
printf '\ntoken = DO_NOT_PRINT\n' >> "$repo/manifests/git.config"
g add manifests/git.config; g commit -qm 'unsafe intermediate'
g revert --no-edit HEAD > /dev/null
fail; ! grep -q DO_NOT_PRINT "$sandbox/output"
pass 'intermediate secret remains blocked despite clean final diff'
reset_fixture
# Allowed deletion and re-addition both receive previews and explicit approval.
g rm -q manifests/vscode-settings.json
g restore --staged manifests/vscode-settings.json
cli --dry-run > "$sandbox/output"; grep -q 'deleted file' "$sandbox/output"
run 's\ns\n'
cp "$root/manifests/vscode-settings.json" "$repo/manifests/vscode-settings.json"
cli --dry-run > "$sandbox/output"; grep -q Adicionado "$sandbox/output"
run 's\ns\n'
pass 'allowlisted deletions and additions staged only after approval'
reset_fixture
# Revalidation catches edits made while the user considers the preview.
(
    CW_ROOT="$sandbox/source"; . "$CW_ROOT/lib/setup.sh"; . "$CW_ROOT/lib/dotfiles.sh"
    cw_confirm() { printf '\n# concurrent\n' >> "$repo/manifests/git.config"; return 0; }
    printf '\n# initial\n' >> "$repo/manifests/git.config"
    if cw_dotfiles sync > "$sandbox/output" 2>&1; then exit 1; fi
    grep -q 'mudou depois' "$sandbox/output"
)
pass 'concurrent edit during confirmation blocks commit'
reset_fixture
(
    CW_ROOT="$sandbox/source"; . "$CW_ROOT/lib/setup.sh"; . "$CW_ROOT/lib/dotfiles.sh"
    cw_is_ubuntu() { return 0; }
    uname() { case "$1" in -s) printf Linux ;; -m) printf x86_64 ;; esac; }
    cw_dotfiles sync --status > "$sandbox/output"
    uname() { case "$1" in -s) printf Darwin ;; -m) printf arm64 ;; esac; }
    cw_dotfiles sync --dry-run > "$sandbox/output"
)
pass 'macOS/Ubuntu detection contracts (native host utilities)'
PATH="$HOME/.local/bin:$PATH" /bin/bash "$sandbox/source/install.sh" </dev/null > "$sandbox/output"
rm -rf "$sandbox/source"
"$HOME/.local/bin/workspace" dotfiles sync --status > "$sandbox/output"
grep -q SKIP "$sandbox/output"
cmp "$HOME/.zshrc" "$sandbox/zsh.before"; cmp "$HOME/.gitconfig" "$sandbox/git.before"
pass 'installed sync survives initial clone deletion and preserves personal files'
printf '\n%s verificações concluídas.\n' "$checks"
