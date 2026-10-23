#!/bin/bash
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
sandbox=$(mktemp -d "$root/tests/.bootstrap.XXXXXX")
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox/home with spaces"
export SHELL=/bin/bash
unset ZDOTDIR
mkdir -p "$HOME" "$sandbox/source" "$sandbox/elsewhere"
cp -R "$root/bin" "$root/lib" "$root/modules" "$root/platforms" "$root/manifests" "$root/install.sh" "$sandbox/source/"
source_dir="$sandbox/source"
export PATH="$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
checks=0
pass() { checks=$((checks + 1)); printf 'ok %s - %s\n' "$checks" "$*"; }
install_cli() { /bin/bash "$source_dir/install.sh" </dev/null > "$sandbox/output" 2>&1; }
install_cli
[ -d "$HOME/.local/state/config-workplace" ]
config-workplace --version | grep -q '0.2.2'
workspace --version | grep -q '0.2.2'
workspace dotfiles --help | grep -q 'terminal-fragment'
printf '#!/bin/bash\nprintf custom-workspace\n' > "$HOME/.local/bin/workspace"
chmod +x "$HOME/.local/bin/workspace"
install_cli
[ "$(workspace)" = custom-workspace ]
pass 'instalação isolada, versão e workspace preexistente preservado'
(cd "$sandbox/elsewhere" && config-workplace --help && config-workplace list) > "$sandbox/commands"
grep -q 'indisponíveis' "$sandbox/commands"
pass 'execução em outro diretório'
mv "$source_dir" "$sandbox/hidden-source"
(cd / && config-workplace --help && config-workplace --version && config-workplace list) >/dev/null
mv "$sandbox/hidden-source" "$source_dir"
pass 'independência do clone renomeado'
install_cli
config-workplace list >/dev/null
pass 'reinstalação idempotente'
printf 'personal data\n' > "$HOME/.local/share/config-workplace/custom.txt"
if install_cli; then exit 1; fi
[ "$(cat "$HOME/.local/share/config-workplace/custom.txt")" = 'personal data' ]
rm "$HOME/.local/share/config-workplace/custom.txt"
pass 'arquivo desconhecido na instalação exige confirmação'
cp "$source_dir/lib/cli.sh" "$sandbox/cli.saved"
rm "$source_dir/lib/cli.sh"
if install_cli; then exit 1; fi
config-workplace --version >/dev/null
cp "$sandbox/cli.saved" "$source_dir/lib/cli.sh"
pass 'arquivo ausente preserva instalação anterior'
printf '\nreturn 42\n' >> "$source_dir/lib/cli.sh"
if install_cli; then exit 1; fi
config-workplace list >/dev/null
cp "$sandbox/cli.saved" "$source_dir/lib/cli.sh"
pass 'falha na validação preserva instalação anterior'
# Fail only when the entry has reached its final location, exercising rollback.
cat >> "$source_dir/lib/cli.sh" <<'FAILURE'
case "$0" in */.local/share/config-workplace/bin/config-workplace) exit 37 ;; esac
FAILURE
if install_cli; then exit 1; fi
config-workplace --version | grep -q '0.2.2'
cp "$sandbox/cli.saved" "$source_dir/lib/cli.sh"
pass 'falha após substituição restaura instalação anterior'
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
printf '# configuração pessoal\n' > "$HOME/.profile"
printf 'n\n' | /bin/bash "$source_dir/install.sh" > "$sandbox/output"
[ "$(cat "$HOME/.profile")" = '# configuração pessoal' ]
pass 'recusa de alteração do PATH'
printf 's\ns\n' | /bin/bash "$source_dir/install.sh" > "$sandbox/output"
[ "$(grep -c 'export PATH=' "$HOME/.profile")" -eq 1 ]
found=0
for file in "$HOME"/.profile.config-workplace-backup.*; do
    [ "$(cat "$file")" = '# configuração pessoal' ]; found=1
done
[ "$found" -eq 1 ]
install_cli
[ "$(grep -c 'export PATH=' "$HOME/.profile")" -eq 1 ]
pass 'PATH com backup e sem duplicações'
/bin/bash -c '. "$HOME/.profile"; cd /; config-workplace --help' >/dev/null
pass 'comando acessível pelo PATH configurado'
export SHELL=/bin/bash
rm "$HOME/.profile"
printf '# bash profile\n' > "$HOME/.bash_profile"
printf 's\n' | /bin/bash "$source_dir/install.sh" > "$sandbox/output"
grep -q 'export PATH=' "$HOME/.bash_profile"
[ ! -e "$HOME/.profile" ]
pass 'Bash respeita precedência do arquivo de login'
# Unknown command is never replaced without consent.
printf '#!/bin/bash\nprintf custom\n' > "$HOME/.local/bin/config-workplace"
cp "$HOME/.local/bin/config-workplace" "$sandbox/custom"
if install_cli; then exit 1; fi
cmp "$sandbox/custom" "$HOME/.local/bin/config-workplace"
pass 'comando desconhecido preservado sem confirmação'
printf 's\nn\n' | /bin/bash "$source_dir/install.sh" > "$sandbox/output"
"$HOME/.local/bin/config-workplace" --help >/dev/null
pass 'substituição autorizada de comando desconhecido'
rm -rf "$source_dir"
(cd / && "$HOME/.local/bin/config-workplace" --help && "$HOME/.local/bin/config-workplace" --version && "$HOME/.local/bin/config-workplace" list) >/dev/null
env -i HOME="$HOME" PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/bash -ic 'cd /; config-workplace --version' > "$sandbox/new-session" 2>/dev/null
grep -q '0.2.2' "$sandbox/new-session"
pass 'independência após exclusão definitiva da cópia original'
# Execute the installed module after deleting its source; all tools/network mocked.
mkdir -p "$sandbox/mock-bin" "$HOME/.nvm"
for tool in git gh npm pnpm wget jq rg fzf brew code; do
    printf '#!/bin/bash\necho mock-version\n' > "$sandbox/mock-bin/$tool"
done
cat > "$sandbox/mock-bin/node" <<'MOCK'
#!/bin/bash
case "$1" in --version) echo v22.1.0 ;; -p) echo MockLTS ;; *) exit 1 ;; esac
MOCK
cat > "$sandbox/mock-bin/curl" <<'MOCK'
#!/bin/bash
printf 'version\tdate\tfiles\tnpm\tv8\tuv\tzlib\topenssl\tmodules\tlts\n'
printf 'v22.1.0\tdate\tfiles\tnpm\tv8\tuv\tzlib\topenssl\tmodules\tMockLTS\n'
MOCK
cat > "$sandbox/mock-bin/uname" <<'MOCK'
#!/bin/bash
case "$1" in -s) echo Darwin ;; -m) echo arm64 ;; esac
MOCK
printf 'nvm() { echo mock-version; }\n' > "$HOME/.nvm/nvm.sh"
chmod +x "$sandbox/mock-bin/"*
PATH="$sandbox/mock-bin:/usr/bin:/bin" NVM_DIR="$HOME/.nvm" "$HOME/.local/bin/config-workplace" initial dev --dry-run > "$sandbox/module-output"
grep -q 'Dry-run' "$sandbox/module-output"
grep -q 'SKIP.*Node' "$sandbox/module-output"
pass 'módulo instalado executa dry-run sem clone nem rede'

if "$HOME/.local/bin/config-workplace" update >/dev/null 2>&1; then exit 1; fi
if "$HOME/.local/bin/config-workplace" list extra >/dev/null 2>&1; then exit 1; fi
pass 'comandos futuros e argumentos inválidos rejeitados'
for file in "$root/install.sh" "$root/bin/config-workplace" "$root/lib/cli.sh" "$root/tests/bootstrap.sh"; do /bin/bash -n "$file"; done
pass "sintaxe e execução com $('/bin/bash' --version | head -n 1)"
printf '\n%s verificações concluídas.\n' "$checks"
