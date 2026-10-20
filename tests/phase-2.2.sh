#!/bin/bash
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/cw-phase22.XXXXXX")
sandbox=$(CDPATH= cd -- "$sandbox" && pwd -P)
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox/home" TMPDIR="$sandbox" SHELL=/bin/bash
mkdir -p "$HOME"
CW_ROOT=$root
. "$root/lib/setup.sh"
. "$root/modules/initial-dev.sh"
checks=0
pass() { checks=$((checks + 1)); printf 'ok %s - %s\n' "$checks" "$*"; }
real_node=$(command -v node)
[ -n "$real_node" ] || { echo 'Node necessário apenas para testes do editor'; exit 1; }
cw_os=macos
# Real JSONC logic against isolated files; no editor is started.
cw_settings_path
mkdir -p "${cw_settings%/*}"
printf '{\n // pessoal\n "editor.fontSize": 18,\n "unrelated": "https://example.com",\n}\n' > "$cw_settings"
cp "$cw_settings" "$sandbox/original"
cw_settings plan > "$sandbox/plan"
grep -q 'conflito, local=18 -> 16' "$sandbox/plan"
grep -q 'editor.tabSize: ausente' "$sandbox/plan"
cmp "$cw_settings" "$sandbox/original"
pass 'dry-run JSONC: conflito e ausências sem alterações'
digest=$(cw_settings hash)
cw_settings apply editor.tabSize "$digest" > "$sandbox/apply"
grep -q '// pessoal' "$cw_settings"
grep -q 'https://example.com' "$cw_settings"
backup=$(sed -n 's/^\[BACKUP\] //p' "$sandbox/apply")
cmp "$backup" "$sandbox/original"
pass 'inclusão granular mantém comentários, chaves extras e backup exato'
digest=$(cw_settings hash)
cw_settings apply editor.fontSize "$digest" >/dev/null
cw_settings plan editor.fontSize | grep -q SKIP
pass 'conflito alterado somente por aplicação explícita'
cp "$cw_settings" "$sandbox/before-idempotent"
cw_settings apply editor.fontSize "$(cw_settings hash)"
cmp "$cw_settings" "$sandbox/before-idempotent"
pass 'configuração existente idempotente'
digest=$(cw_settings hash)
printf '\n' >> "$cw_settings"
cp "$cw_settings" "$sandbox/changed"
if cw_settings apply editor.rulers "$digest"; then exit 1; fi
cmp "$cw_settings" "$sandbox/changed"
pass 'alteração concorrente impede escrita'
rm "$cw_settings"
cw_settings apply editor.tabSize "$(cw_settings hash)"
[ -f "$cw_settings" ]
pass 'settings ausente criado com a chave aprovada'
printf '{bad' > "$cw_settings"
if cw_settings plan; then exit 1; fi
[ "$(cat "$cw_settings")" = '{bad' ]
pass 'JSON inválido preservado'
rm "$cw_settings"
ln -s "$sandbox/original" "$cw_settings"
if cw_settings plan; then exit 1; fi
cmp "$sandbox/original" "$sandbox/original"
rm "$cw_settings"
pass 'symlink de configuração preservado'
# Extensions: mock executable with persistent installation state and failure injection.
mkdir -p "$sandbox/mock-bin"
export CW_TEST_STATE="$sandbox"
cat > "$sandbox/mock-bin/code" <<'MOCK'
#!/bin/bash
case "$1" in
 --version) echo 1.0 ;;
 --list-extensions) cat "$CW_TEST_STATE/extensions" ;;
 --install-extension)
   echo "$*" >> "$CW_TEST_STATE/mutations"
   [ ! -f "$CW_TEST_STATE/fail" ] || exit 1
   echo "$2" >> "$CW_TEST_STATE/extensions" ;;
 *) exit 1 ;;
esac
MOCK
chmod +x "$sandbox/mock-bin/code"
export PATH="$sandbox/mock-bin:$PATH"
printf 'esbenp.prettier-vscode\nextra.extension\n' > "$sandbox/extensions"
: > "$sandbox/mutations"
cp "$root/manifests/vscode-settings.json" "$cw_settings"
cw_editor_apply <<< n
[ ! -s "$sandbox/mutations" ]
pass 'recusa da extensão ausente não é falha'
cw_editor_apply <<< s
[ "$(wc -l < "$sandbox/mutations" | tr -d ' ')" = 1 ]
grep -q '^extra.extension$' "$sandbox/extensions"
grep -q '^--install-extension usernamehw.errorlens$' "$sandbox/mutations"
pass 'extensão ausente instalada sem atualizar existente nem remover extra'
cw_editor_apply </dev/null
[ "$(wc -l < "$sandbox/mutations" | tr -d ' ')" = 1 ]
pass 'reexecução de extensões idempotente'
# Refuse all six settings changes; preserve bytes.
printf '{"editor.fontSize": 23}' > "$cw_settings"
cp "$cw_settings" "$sandbox/refused"
cw_editor_apply </dev/null
cmp "$cw_settings" "$sandbox/refused"
pass 'recusa de configurações preserva valores locais'
printf 'esbenp.prettier-vscode\n' > "$sandbox/extensions"
touch "$sandbox/fail"
if cw_editor_apply <<< s; then exit 1; fi
cmp "$cw_settings" "$sandbox/refused"
pass 'falha parcial de extensão não perde configurações'
rm "$sandbox/fail"
cw_vscode_probe
[ "$cw_code" = "$sandbox/mock-bin/code" ]
pass 'VS Code existente via PATH detectado'
# No actual /Applications or package database is consulted in the absent-app test:
# isolate the probe via a Bash child with test mocks for filesystem predicates.
(
  command() { case "$*" in '-v code'|'-v dpkg-query'|'-v snap'|'-v flatpak') return 1 ;; *) builtin command "$@" ;; esac; }
  export CW_VSCODE_APP="$sandbox/Fake.app"
  mkdir -p "$CW_VSCODE_APP/Contents/Resources/app/bin"
  cp "$sandbox/mock-bin/code" "$CW_VSCODE_APP/Contents/Resources/app/bin/code"
  cw_vscode_probe
  [ "$cw_code" = "$CW_VSCODE_APP/Contents/Resources/app/bin/code" ]
)
pass 'aplicativo macOS sem code no PATH detectado pelo binário interno'
# pnpm: no real installer may be invoked.
(
  pnpm() { echo 9.1.0; }
  cw_tool_probe pnpm
  cw_install_pnpm() { echo forbidden; exit 99; }
  cw_install_tool pnpm > "$sandbox/pnpm-skip"
  grep -q SKIP "$sandbox/pnpm-skip"
)
pass 'pnpm funcional de outra origem não é reinstalado'
(
  pnpm() { return 1; }
  if cw_install_tool pnpm; then exit 1; fi
)
pass 'pnpm quebrado preservado'
printf '{"version":"10.1.0","engines":{"node":">=18.12"}}' | "$real_node" "$root/lib/pnpm-metadata.js" | grep -q 10.1.0
if printf '{"version":"10.1.0","engines":{"node":">=999"}}' | "$real_node" "$root/lib/pnpm-metadata.js"; then exit 1; fi
pass 'compatibilidade pnpm validada sem instalar ou trocar Node'
# Platform adapters and absence: all mutation boundaries mocked.
(
  ready=0
  cw_tool_probe() { [ "$ready" -eq 1 ]; }
  dpkg-query() { return 1; }
  cw_privileged() { printf '%s\n' "$*" >> "$sandbox/apt"; ready=1; }
  cw_os=ubuntu
  cw_install_tool rg
  grep -q 'apt-get install --no-upgrade -y ripgrep' "$sandbox/apt"
  ready=0; cw_os=macos
  cw_probe() { return 0; }
  brew() { printf '%s\n' "$*" > "$sandbox/brew"; ready=1; }
  cw_install_tool rg
  grep -q 'install ripgrep' "$sandbox/brew"
)
pass 'Ubuntu/macOS: rg mapeado a ripgrep, sem upgrade automático'
(
  cw_vscode_probe() { [ -f "$sandbox/code-ready" ]; }
  cw_os=ubuntu; cw_arch=arm64
  cw_fetch() { printf '%s' "$1" > "$sandbox/url"; echo mock-deb; }
  cw_privileged() { printf '%s\n' "$*" > "$sandbox/vscode-apt"; touch "$sandbox/code-ready"; }
  cw_install_vscode
  grep -q 'latest/linux-deb-arm64/stable' "$sandbox/url"
  grep -q 'apt-get install --no-upgrade -y' "$sandbox/vscode-apt"
  rm "$sandbox/code-ready"
  cw_os=macos; cw_probe() { return 0; }
  brew() { printf '%s\n' "$*" > "$sandbox/vscode-brew"; touch "$sandbox/code-ready"; }
  cw_install_vscode
  grep -q 'install --cask visual-studio-code' "$sandbox/vscode-brew"
)
pass 'VS Code ausente: instaladores por plataforma e verificação posterior'
# Full dry-run and refusal with both phases; no network, no real tool probes.
(
  cw_platform() { cw_os=macos; cw_arch=arm64; }
  cw_probe() { cw_version=v22.1.0; return 0; }
  cw_load_nvm() { return 0; }
  cw_lts_major() { echo 22; }
  nvm() { echo mock; }
  node() { if [ "$1" = -p ]; then echo LTS; else "$real_node" "$@"; fi; }
  cw_tool_probe() { [ "$1" != pnpm ]; }
  cw_resolve_pnpm() { pnpm_version=10.1.0; }
  cw_vscode_probe() { cw_code="$sandbox/mock-bin/code"; cw_code_origin=mock; return 0; }
  cw_install_tool() { echo forbidden >> "$sandbox/forbidden"; return 1; }
  cp "$cw_settings" "$sandbox/full-before"
  cw_initial_dev --dry-run > "$sandbox/full-plan"
  grep -q 'Instalar pnpm' "$sandbox/full-plan"
  grep -q 'SKIP.*Git\|SKIP.*git' "$sandbox/full-plan"
  cw_initial_dev <<< n
  [ ! -e "$sandbox/forbidden" ]
  cmp "$cw_settings" "$sandbox/full-before"
)
pass 'plano completo das duas fases, dry-run e recusa sem mutações'
(
  # Exercise the real pnpm installer using a fake npm writing only to fake HOME.
  cw_probe() { return 0; }
  pnpm_version=10.1.0
  node() { echo "$real_node"; }
  cw_local_path() { return 0; }
  npm() {
    printf '%s\n' "$*" > "$sandbox/npm-args"
    mkdir -p "$HOME/.local/share/config-workplace-pnpm/bin"
    printf '#!/bin/bash\necho 10.1.0\n' > "$HOME/.local/share/config-workplace-pnpm/bin/pnpm"
    chmod +x "$HOME/.local/share/config-workplace-pnpm/bin/pnpm"
  }
  cw_install_pnpm
  grep -q -- '--engine-strict' "$sandbox/npm-args"
  grep -q 'pnpm@10.1.0' "$sandbox/npm-args"
  (cd /; "$HOME/.local/bin/pnpm") | grep -q 10.1.0
)
pass 'pnpm ausente instalado isoladamente e executável fora do clone'
# Interactive settings approval consumes user input, not the keys stream.
printf 'esbenp.prettier-vscode\nusernamehw.errorlens\n' > "$sandbox/extensions"
printf '{"editor.fontSize":23}' > "$cw_settings"
cw_editor_apply <<'ANSWERS'
s
n
n
n
n
n
ANSWERS
cw_settings plan editor.fontSize | grep -q SKIP
cw_settings plan editor.tabSize | grep -q ausente
pass 'aprovação granular aplica só a chave aceita e mantém as demais pendentes'
(
  cw_tool_probe() { return 1; }
  cw_os=macos
  xcode-select() { printf '%s\n' "$*" > "$sandbox/xcode"; }
  cw_install_tool build-essential
  grep -q -- '--install' "$sandbox/xcode"
)
pass 'Command Line Tools ausentes abrem instalador nativo após autorização'
(
  cw_vscode_probe() { cw_code="$sandbox/mock-bin/code"; return 0; }
  command() { case "$*" in '-v code') return 1 ;; *) builtin command "$@" ;; esac; }
  cw_code_launcher <<< n
  [ ! -e "$HOME/.local/bin/code" ]
  cw_local_path() { return 0; }
  cw_code_launcher <<< s
  [ "$(readlink "$HOME/.local/bin/code")" = "$sandbox/mock-bin/code" ]
  "$HOME/.local/bin/code" --version | grep -q 1.0
)
pass 'CLI ausente: recusa preserva estado e aprovação cria link ao aplicativo'
(
  printf '# pessoal\n' > "$HOME/.bash_profile"
  cp "$HOME/.bash_profile" "$sandbox/profile-before"
  if cw_local_path <<< n; then exit 1; fi
  cmp "$HOME/.bash_profile" "$sandbox/profile-before"
  cw_local_path <<< s
  found=0
  for backup in "$HOME"/.bash_profile.config-workplace-backup.*; do
    cmp "$backup" "$sandbox/profile-before"; found=1
  done
  [ "$found" -eq 1 ]
  cw_local_path </dev/null
  [ "$(grep -c 'export PATH=' "$HOME/.bash_profile")" = 1 ]
  /bin/bash -c '. "$HOME/.bash_profile"; cd /; pnpm --version' | grep -q 10.1.0
)
pass 'PATH com confirmação, backup, idempotência e pnpm em nova sessão'
for file in "$root"/lib/*.sh "$root"/platforms/*.sh "$root"/modules/*.sh; do /bin/bash -n "$file"; done
printf '\n%s verificações concluídas.\n' "$checks"
