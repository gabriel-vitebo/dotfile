#!/bin/bash
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
work=$(mktemp -d "${TMPDIR:-/tmp}/cw-path.XXXXXX")
work=$(CDPATH= cd -- "$work" && pwd -P)
trap 'rm -rf "$work"' EXIT
export SHELL=/bin/bash PATH=/usr/bin:/bin:/usr/sbin:/sbin
unset ZDOTDIR BASH_ENV ENV
CW_ROOT=$root
. "$root/lib/dev-safety.sh"
cw_log() { printf '%s: %s\n' "$1" "$2"; }
cw_confirm() { local answer; IFS= read -r answer && [ "$answer" = s ]; }
fresh() {
    export HOME="$work/$1"
    mkdir -p "$HOME/.local/bin"
    printf '#!/bin/bash\necho test-cli\n' > "$HOME/.local/bin/config-workplace"
    chmod +x "$HOME/.local/bin/config-workplace"
}
session() {
    env -i HOME="$HOME" PATH=/usr/bin:/bin:/usr/sbin:/sbin "$SHELL" "$1" 'cd /; config-workplace' </dev/null 2>/dev/null | grep -qx test-cli
}
fresh ubuntu
cat > "$HOME/.profile" <<'PROFILE'
# Ubuntu default
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi
PROFILE
printf '# personal\nexport PERSONAL=yes\n' > "$HOME/.bashrc"
chmod 640 "$HOME/.bashrc"
cp -p "$HOME/.bashrc" "$work/rc-before"
cp -p "$HOME/.profile" "$work/profile-before"
# Inherited PATH alone is insufficient evidence of persistence.
PATH="$HOME/.local/bin:$PATH" cw_local_path <<< n > "$work/decline" && exit 1
cmp "$work/rc-before" "$HOME/.bashrc"
cmp "$work/profile-before" "$HOME/.profile"
! compgen -G "$HOME/.bashrc.config-workplace-backup.*" >/dev/null
cw_local_path <<< s > "$work/plan"
cmp "$work/profile-before" "$HOME/.profile"
grep -Fq "$HOME/.bashrc: PATH ausente" "$work/plan"
for backup in "$HOME"/.bashrc.config-workplace-backup.*; do cmp "$work/rc-before" "$backup"; done
[ "$(stat -c %a "$HOME/.bashrc" 2>/dev/null || stat -f %Lp "$HOME/.bashrc")" = 640 ]
for mode in -ic -lc -lic; do session "$mode"; done
cp "$HOME/.bashrc" "$work/rc-after"
cw_local_path </dev/null > "$work/repeat"
cmp "$work/rc-after" "$HOME/.bashrc"
[ "$(find "$HOME" -name '*.config-workplace-backup.*' | wc -l)" -eq 1 ]
printf 'ok - Ubuntu, sessões Bash, recusa, preview, backup, permissões e idempotência\n'

fresh shared
printf '. "$HOME/.bashrc"\n' > "$HOME/.bash_profile"
cp "$HOME/.bash_profile" "$work/shared-before"
cw_local_path <<< s > "$work/shared-plan"
cmp "$work/shared-before" "$HOME/.bash_profile"
for mode in -ic -lc -lic; do session "$mode"; done
printf 'ok - login que carrega bashrc recebe uma única integração\n'

fresh independent
printf '# login personal\n' > "$HOME/.bash_login"
cw_local_path <<< $'s\ns' > "$work/independent-plan"
[ ! -e "$HOME/.profile" ]
for mode in -ic -lc -lic; do session "$mode"; done
printf 'ok - precedência bash_login e arquivos independentes\n'

fresh equivalent
printf 'export PATH="$PATH:$HOME/.local/bin"\n' > "$HOME/.bashrc"
printf '. "$HOME/.bashrc"\n' > "$HOME/.profile"
cp "$HOME/.bashrc" "$work/equivalent-before"
cw_local_path </dev/null > "$work/equivalent-plan"
cmp "$HOME/.bashrc" "$work/equivalent-before"
! compgen -G "$HOME/*.config-workplace-backup.*" >/dev/null
printf 'ok - configuração funcionalmente equivalente sem alterações\n'

fresh links
printf '# corporate\n' > "$work/corporate"
cp "$work/corporate" "$work/corporate-before"
ln -s "$work/corporate" "$HOME/.bashrc"
ln -s "$work/corporate" "$HOME/.profile"
if cw_local_path <<< $'s\ns' > "$work/link-plan"; then exit 1; fi
cmp "$work/corporate" "$work/corporate-before"
[ -L "$HOME/.bashrc" ] && [ -L "$HOME/.profile" ]
printf 'ok - symlinks desconhecidos e destino corporativo preservados\n'

fresh unreachable
printf 'return\nexport PATH="$HOME/.local/bin:$PATH"\n' > "$HOME/.bashrc"
printf '. "$HOME/.bashrc"\n' > "$HOME/.profile"
cp "$HOME/.bashrc" "$work/unreachable-before"
if cw_local_path <<< $'s\ns' > "$work/unreachable-plan"; then exit 1; fi
cmp "$HOME/.bashrc" "$work/unreachable-before"
printf 'ok - referência existente sem efeito não recebe duplicação\n'

if command -v zsh >/dev/null; then
    export SHELL
    SHELL=$(command -v zsh)
    for variant in default inherited startup external; do
        fresh "zsh $variant"
        unset ZDOTDIR
        case "$variant" in
            external) export ZDOTDIR="$work/external zsh config"; mkdir -p "$ZDOTDIR" ;;
            inherited) export ZDOTDIR="$HOME/zsh config"; mkdir -p "$ZDOTDIR" ;;
            startup) mkdir -p "$HOME/zsh config"; printf 'export ZDOTDIR="$HOME/zsh config"\n' > "$HOME/.zshenv" ;;
        esac
        location=${ZDOTDIR:-$HOME}
        [ "$variant" != startup ] || location="$HOME/zsh config"
        printf '# personal zsh\n' > "$location/.zshrc"
        cw_local_path <<< $'s\ns' > "$work/zsh-plan"
        cw_local_path </dev/null > "$work/zsh-repeat"
        for mode in -ic -lc -lic; do
            env -i HOME="$HOME" PATH="$PATH" ${ZDOTDIR+"ZDOTDIR=$ZDOTDIR"} "$SHELL" "$mode" 'cd /; config-workplace' </dev/null 2>/dev/null | grep -qx test-cli
        done
        [ "$(grep -c '^# >>> config-workplace PATH >>>' "$location/.zshrc")" = 1 ]
    done
    printf 'ok - Zsh sem ZDOTDIR, herdado e definido em .zshenv\n'
else
    printf 'SKIP - Zsh indisponível; cenários Zsh exigem binário real\n'
fi
