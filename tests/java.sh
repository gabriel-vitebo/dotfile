#!/bin/bash
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/cw-java.XXXXXX")
sandbox=$(cd "$sandbox" && pwd -P)
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox/home"
export SHELL=/bin/bash
unset JAVA_HOME SDKMAN_DIR SDKMAN_CANDIDATES_DIR ZDOTDIR
mkdir -p "$HOME" "$sandbox/bin" "$sandbox/source"
cp -R "$root/bin" "$root/lib" "$root/modules" "$root/platforms" "$root/manifests" "$root/install.sh" "$sandbox/source/"
CW_ROOT="$sandbox/source"
. "$CW_ROOT/lib/setup.sh"
. "$CW_ROOT/modules/java.sh"
export PATH="$sandbox/bin:/usr/bin:/bin:/usr/sbin:/sbin"
checks=0
pass() { checks=$((checks + 1)); printf 'ok %s - %s\n' "$checks" "$*"; }
# Fail closed if any test accidentally attempts network or a real installer.
curl() { echo 'unexpected network' >&2; return 99; }
sudo() { echo 'unexpected privilege escalation' >&2; return 99; }
cw_platform() { cw_os=ubuntu; cw_arch=x86_64; }
cw_vscode_probe() { return 1; }
fixture_jdk() {
    mkdir -p "$1/bin"
    printf '#!/bin/bash\necho '\''openjdk version "%s.0.1"'\'' >&2\n' "$2" > "$1/bin/java"
    printf '#!/bin/bash\necho '\''javac %s.0.1'\''\n' "$2" > "$1/bin/javac"
    chmod +x "$1/bin/java" "$1/bin/javac"
}
fixture_tool() { printf '#!/bin/bash\necho "%s fixture"\n' "$2" > "$1"; chmod +x "$1"; }
fixture_jdk "$sandbox" 21
fixture_tool "$sandbox/bin/mvn" Maven
fixture_tool "$sandbox/bin/gradle" Gradle
cw_fetch() {
    case "$1" in
        *available_releases) echo '{"available_lts_releases":[17,21,29],"most_recent_lts":29,"most_recent_feature_release":30}' ;;
        */java/*) printf ' Temurin | | 30.0.1 | tem | | 30.0.1-tem\n | | 29.0.2 | tem | | 29.0.2-tem\n | | 29.0.10 | tem | | 29.0.10-tem\n | | 29.0.20.ea | tem | | 29.0.20.ea-tem\n' ;;
        */maven/*) echo ' 3.9.9 3.10.0 4.0.0-rc-1' ;;
        */gradle/*) echo ' 9.1.0 9.2.0 10.0.0-rc-1' ;;
        *compatibility.html) echo '<p>A JVM version between 17 and 29 is required to execute Gradle.</p>' ;;
        *) return 1 ;;
    esac
}
cw_os=ubuntu; cw_arch=x86_64
cw_java_probe; [ "$java_major" = 21 ]
cw_java_origin "$java_bin" | grep -q 'externa'
pass 'JDK funcional externo, sem JAVA_HOME ou SDKMAN!'
cw_java --dry-run > "$sandbox/full"
grep -q 'SDKMAN! ausente e desnecessário' "$sandbox/full"
[ ! -e "$HOME/.sdkman" ]
pass 'SDKMAN! ausente e desnecessário; Maven/Gradle SKIP'
cw_java </dev/null > "$sandbox/repeat"
! grep -q 'Continuar' "$sandbox/repeat"
pass 'idempotência sem confirmação nem mutações para ferramentas funcionais'
# Function mock isolates absence from Apple system launchers and host JDKs.
(
 cw_java_probe() { java_major=; return 1; }
 cw_java_sdk_prepare() { cw_log INSTALL 'SDKMAN! necessário'; }
 cw_java --dry-run > "$sandbox/no-java"
)
grep -q 'Temurin 29.0.10-tem' "$sandbox/no-java"
pass 'Java ausente: LTS dinâmica futura, maior patch; não seleciona feature/EA'
cp "$sandbox/bin/javac" "$sandbox/javac"
printf '#!/bin/bash\nexit 1\n' > "$sandbox/bin/javac"
state=0; cw_java_probe || state=$?; [ "$state" -eq 3 ]
(
 cw_java_sdk_prepare() { cw_log INSTALL 'SDKMAN! necessário'; }
 cw_java --dry-run > "$sandbox/runtime"
)
grep -q 'Runtime sem compilador' "$sandbox/runtime"
mv "$sandbox/javac" "$sandbox/bin/javac"
pass 'runtime sem javac propõe JDK com confirmação específica'
(
 cw_fetch() { return 1; }
 if cw_java_lts; then exit 1; fi
 cw_java_probe() { java_major=; return 1; }
 if cw_java --dry-run > "$sandbox/unresolved"; then exit 1; fi
)
grep -q 'Não foi possível resolver' "$sandbox/unresolved"
pass 'falha de resolução bloqueia sem inventar versão'
cw_java_lts; [ "$java_candidate" = 29.0.10-tem ]
[ "$(cw_java_build_version maven 21)" = 3.10.0 ]
[ "$(cw_java_build_version gradle 21)" = 9.2.0 ]
if cw_java_build_version gradle 11; then exit 1; fi
if cw_java_build_version maven 7; then exit 1; fi
pass 'estáveis Maven/Gradle e compatibilidade; RC rejeitado'
(
 export JAVA_HOME="$sandbox"
 cw_java --dry-run > "$sandbox/java-home"
 [ "$JAVA_HOME" = "$sandbox" ]
 export JAVA_HOME="$HOME/missing"
 cw_java --dry-run > "$sandbox/conflicting-home"
)
grep -q 'JAVA_HOME existente preservado' "$sandbox/java-home"
grep -q 'JAVA_HOME inválido' "$sandbox/conflicting-home"
pass 'JAVA_HOME preservado e divergência diagnosticada'
printf 'private fixture\n' > "$HOME/personal"
mkdir -p "$HOME/.m2" "$HOME/.gradle"
cp "$HOME/personal" "$HOME/.m2/settings.xml"
cp "$HOME/personal" "$HOME/.gradle/gradle.properties"
(
 cw_java_sdk_prepare() { cw_log INSTALL 'SDKMAN! necessário'; }
 cw_java_tool_probe() { return 1; }
 cw_java --dry-run > "$sandbox/missing-tools"
 printf 'n\n' | cw_java > "$sandbox/decline"
)
grep -q 'INSTALL.*maven' "$sandbox/missing-tools"
grep -q 'INSTALL.*gradle' "$sandbox/missing-tools"
grep -q 'Operação cancelada' "$sandbox/decline"
cmp "$HOME/personal" "$HOME/.m2/settings.xml"
cmp "$HOME/personal" "$HOME/.gradle/gradle.properties"
[ ! -e "$HOME/.sdkman" ]
pass 'Maven/Gradle ausentes, plano/recusa sem alterações ou leitura de credenciais'
mkdir -p "$HOME/.sdkman/bin" "$HOME/.sdkman/var"
printf '21.0.0\n' > "$HOME/.sdkman/var/version"
printf 'touch "$HOME/DO-NOT-SOURCE"\n' > "$HOME/.sdkman/bin/sdkman-init.sh"
cw_java_sdk_probe; [ "$sdk_version" = 21.0.0 ]
cw_java --dry-run > "$sandbox/sdk-existing"
[ ! -e "$HOME/DO-NOT-SOURCE" ]
pass 'SDKMAN! existente detectado sem carregar função nem alterar arquivos no dry-run'
printf '(' > "$HOME/.sdkman/bin/sdkman-init.sh"
if cw_java_sdk_probe 2>/dev/null; then exit 1; fi
rm -rf "$HOME/.sdkman"
pass 'SDKMAN! quebrado não tratado como ausente'
# Editor mock: preserve extra extension and settings; one approval for each ID.
code_fixture() {
    case "$1" in
        --list-extensions) cat "$sandbox/extensions" ;;
        --install-extension) printf '%s\n' "$2" >> "$sandbox/extensions" ;;
        *) return 1 ;;
    esac
}
echo 'personal.extra' > "$sandbox/extensions"
(
 cw_vscode_probe() { cw_code=code_fixture; return 0; }
 cw_java_editor_plan > "$sandbox/editor-plan"
 [ "${#java_extensions[@]}" -eq 6 ]
 printf 'n\nn\nn\nn\nn\nn\n' | cw_java_editor_apply > "$sandbox/editor-no"
 [ "$(wc -l < "$sandbox/extensions" | tr -d ' ')" = 1 ]
 printf 's\ns\ns\ns\ns\ns\n' | cw_java_editor_apply > "$sandbox/editor-yes"
 cw_java_editor_plan > "$sandbox/editor-repeat"
 [ "${#java_extensions[@]}" -eq 0 ]
)
grep -q personal.extra "$sandbox/extensions"
[ "$(wc -l < "$sandbox/extensions" | tr -d ' ')" = 7 ]
pass 'extensões opcionais, recusa, aprovação individual, extras e idempotência'
grep -q 'VS Code ausente' "$sandbox/full"
pass 'VS Code ausente não bloqueia Java'
for spec in ubuntu:x86_64:linuxx64 ubuntu:aarch64:linuxarm64 macos:x86_64:darwinx64 macos:arm64:darwinarm64; do
 cw_os=${spec%%:*}; rest=${spec#*:}; cw_arch=${rest%%:*}
 [ "$(cw_java_sdk_platform)" = "${rest#*:}" ]
done
pass 'catálogo correto Ubuntu/macOS x86_64/ARM64'
# Real candidate guard, with only SDK transport mocked.
(
 sdk_dir="$HOME/.sdkman"
 cw_java_tool_probe() { return 1; }
 cw_java_sdk_run() {
    mkdir -p "$sdk_dir/candidates/$2/$3/bin"
    fixture_tool "$sdk_dir/candidates/$2/$3/bin/mvn" Maven
 }
 printf 'n\n' | cw_java_install_candidate maven 3.10.0 && exit 1
 [ ! -e "$sdk_dir" ]
 printf 's\n' | cw_java_install_candidate maven 3.10.0
)
pass 'instalador revalida e exige aprovação específica'
(
 cw_java_probe() { java_major=; return 1; }
 cw_java_tool_probe() { return 1; }
 cw_java_sdk_probe() { sdk_dir="$HOME/.sdkman"; sdk_version=1.0.0; return 0; }
 cw_java_sdk_shell() { sdk_shell=/bin/bash; }
 cw_java_install_candidate() {
    echo "$1" >> "$sandbox/partial"
    [ "$1" = java ]
 }
 if printf 's\n' | cw_java > "$sandbox/partial-output"; then exit 1; fi
)
[ "$(cat "$sandbox/partial")" = "$(printf 'java\nmaven')" ]
grep -q 'falha parcial' "$sandbox/partial-output"
pass 'falha parcial interrompe dependências e preserva anteriores'
# Fresh official-installer fixture writes profiles ONLY into isolated HOME.
(
 sdk_dir="$HOME/new-sdkman"; sdk_shell=/bin/bash; sdk_new_version=1.2.3
 sdk_installer='#!/bin/bash
export SDKMAN_VERSION="1.2.3"
# https://api.sdkman.io/2
mkdir -p "$SDKMAN_DIR/bin" "$SDKMAN_DIR/var" "$SDKMAN_DIR/etc"
echo "$SDKMAN_VERSION" > "$SDKMAN_DIR/var/version"
printf ":\n" > "$SDKMAN_DIR/bin/sdkman-init.sh"
echo sdkman_selfupdate_feature=true > "$SDKMAN_DIR/etc/config"
echo unexpected > "$HOME/.bashrc"
echo unexpected > "$ZDOTDIR/.zshrc"'
 export SDKMAN_DIR="$sdk_dir"
 echo personal > "$HOME/.bashrc"
 cw_java_sdk_install
 [ "$(cat "$HOME/.bashrc")" = personal ]
 [ ! -e "$HOME/.zshrc" ]
 grep -q 'sdkman_selfupdate_feature=false' "$sdk_dir/etc/config"
)
pass 'instalador isolado protege startup; nenhuma atualização automática nova'
(
 sdk_dir="$CW_ROOT/sdkman"
 if cw_safe_destination "$sdk_dir"; then exit 1; fi
 ln -s "$CW_ROOT" "$HOME/clone-link"
 if cw_safe_destination "$HOME/clone-link/sdkman"; then exit 1; fi
)
pass 'destinos no clone e ancestrais symlink recusados'
rm -rf "$HOME/.sdkman"
(
 cw_java_tool_probe() { return 1; }
 cw_java_sdk_prepare() { sdk_new_version=1.2.3; cw_log INSTALL 'SDKMAN! necessário'; }
 cw_java_sdk_install() { touch "$HOME/forbidden-install"; }
 printf 's\nn\n' | cw_java > "$sandbox/sdk-decline"
 [ ! -e "$HOME/forbidden-install" ]
)
grep -q 'SDKMAN! recusado' "$sandbox/sdk-decline"
pass 'aprovação geral não substitui aprovação específica do SDKMAN!'
(
 sdk_dir="$HOME/.sdkman"
 mkdir -p "$sdk_dir/candidates/gradle"
 ln -s missing "$sdk_dir/candidates/gradle/current"
 cw_java_tool_probe() { return 1; }
 if printf 's\n' | cw_java_install_candidate gradle 9.2.0; then exit 1; fi
 [ "$(readlink "$sdk_dir/candidates/gradle/current")" = missing ]
)
rm -rf "$HOME/.sdkman"
pass 'seleção default existente, inclusive quebrada, nunca substituída'
(
 sdk_dir="$HOME/.sdkman"
 cw_java_sdk_run() { touch "$HOME/forbidden-install"; }
 cw_java_install_candidate maven 3.10.0 </dev/null
 [ ! -e "$HOME/forbidden-install" ]
)
pass 'revalidação imediatamente antes da instalação mantém ferramenta funcional'
(
 cw_os=macos; cw_arch=arm64
 cw_java_lts; [ "$java_candidate" = 29.0.10-tem ]
 cw_fetch() { echo '<html>unrecognized response</html>'; }
 if cw_java_lts; then exit 1; fi
 if cw_java_build_version gradle 21; then exit 1; fi
)
pass 'resolução no macOS e respostas remotas inválidas bloqueadas'
find "$HOME" -type f -exec cksum {} \; | sort > "$sandbox/before-dry"
cw_java --dry-run > "$sandbox/snapshot-dry"
find "$HOME" -type f -exec cksum {} \; | sort > "$sandbox/after-dry"
cmp "$sandbox/before-dry" "$sandbox/after-dry"
pass 'snapshot de arquivos pessoais idêntico após dry-run'
if /bin/bash "$CW_ROOT/bin/config-workplace" java --yes > "$sandbox/args" 2>&1; then exit 1; fi
pass 'opções não suportadas não contornam confirmação'
(
 sdk_dir="$HOME/prepare-sdk"
 cw_java_sdk_shell() { sdk_shell=/bin/bash; }
 cw_fetch() { printf '#!/bin/bash\nexport SDKMAN_VERSION="9.8.7"\n# https://api.sdkman.io/2\n'; }
 cw_java_sdk_prepare > "$sandbox/prepare"
 [ "$sdk_new_version" = 9.8.7 ]
 [ ! -e "$sdk_dir" ]
 cw_fetch() { echo '<html>invalid installer</html>'; }
 if cw_java_sdk_prepare > "$sandbox/invalid-installer" 2>&1; then exit 1; fi
)
pass 'preparação valida instalador oficial em memória e rejeita conteúdo inválido'
# Simulate the SDK shell contract using actual process isolation and actual installed paths.
mkdir -p "$HOME/lifecycle-sdk/bin" "$HOME/lifecycle-sdk/candidates"
cat > "$HOME/lifecycle-sdk/bin/sdkman-init.sh" <<'SDK'
sdk() {
    case "$1" in
        version) echo 'fixture SDKMAN!' ;;
        install)
            target="$SDKMAN_DIR/candidates/$2/$3"
            mkdir -p "$target/bin"
            case "$2" in
                java)
                    printf '#!/bin/bash\necho '\''openjdk version "29.0.10"'\''\n' > "$target/bin/java"
                    printf '#!/bin/bash\necho "javac 29.0.10"\n' > "$target/bin/javac" ;;
                maven) printf '#!/bin/bash\necho "Maven 3.10.0"\n' > "$target/bin/mvn" ;;
                gradle) printf '#!/bin/bash\necho "Gradle 9.2.0"\n' > "$target/bin/gradle" ;;
            esac
            chmod +x "$target/bin/"*
            ln -s "$3" "$SDKMAN_DIR/candidates/$2/current" ;;
        *) return 1 ;;
    esac
}
for candidate in "$SDKMAN_DIR"/candidates/*/current; do
    [ -d "$candidate" ] || continue
    export PATH="$candidate/bin:$PATH"
done
SDK
(
 sdk_dir="$HOME/lifecycle-sdk"; sdk_shell=/bin/bash
 cw_java_probe() { return 1; }
 cw_java_tool_probe() { return 1; }
 printf 's\n' | cw_java_install_candidate java 29.0.10-tem
 printf 's\n' | cw_java_install_candidate maven 3.10.0
 printf 's\n' | cw_java_install_candidate gradle 9.2.0
)
pass 'SDK runner real em subprocesso instala/valida três fixtures independentes'
# Installed CLI remains complete after the cloned source is deleted.
PATH="$HOME/.local/bin:$PATH" /bin/bash "$CW_ROOT/install.sh" </dev/null > "$sandbox/bootstrap"
rm -rf "$CW_ROOT"
"$HOME/.local/bin/config-workplace" java --dry-run > "$sandbox/permanent"
grep -q 'Java JDK' "$sandbox/permanent"
rm -rf "$HOME/.local/share/config-workplace"
SDKMAN_DIR="$HOME/lifecycle-sdk" /bin/bash -c 'cd /; . "$SDKMAN_DIR/bin/sdkman-init.sh"; java -version; javac -version; mvn -version; gradle --version' > "$sandbox/standalone" 2>&1
grep -q '29.0.10' "$sandbox/standalone"
grep -q 'Maven 3.10.0' "$sandbox/standalone"
grep -q 'Gradle 9.2.0' "$sandbox/standalone"
pass 'CLI sem clone; ferramentas independentes da CLI em nova sessão (fixtures)'
printf '%s verificações concluídas.\n' "$checks"
