# SDKMAN is shell code, not an executable. Inspect without sourcing during planning.
cw_java_sdk_probe() {
    sdk_dir=${SDKMAN_DIR:-$HOME/.sdkman}
    sdk_version=
    [ -e "$sdk_dir" ] || [ -L "$sdk_dir" ] || {
        if command -v sdk >/dev/null 2>&1; then return 2; fi
        return 1
    }
    [ -s "$sdk_dir/bin/sdkman-init.sh" ] && [ -s "$sdk_dir/var/version" ] || return 2
    /bin/bash -n "$sdk_dir/bin/sdkman-init.sh" || return 2
    IFS= read -r sdk_version < "$sdk_dir/var/version" || [ -n "$sdk_version" ] || return 2
    [[ "$sdk_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 2
}
cw_java_sdk_shell() {
    local candidate
    sdk_shell=
    for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash "$(command -v bash)" /bin/bash; do
        [ -x "$candidate" ] || continue
        if "$candidate" -c '[ "${BASH_VERSINFO[0]}" -ge 4 ]'; then sdk_shell=$candidate; return 0; fi
    done
    cw_log REVIEW 'SDKMAN! atual requer Bash 4+. Prepare Bash compatível manualmente; a CLI continua compatível com Bash 3.2.'
    return 1
}
cw_java_sdk_prepare() {
    local prereq
    cw_safe_destination "$sdk_dir" || return 1
    for prereq in curl zip unzip tar; do
        command -v "$prereq" >/dev/null 2>&1 || { cw_log REVIEW "Pré-requisito SDKMAN! ausente: $prereq; prepare e reexecute."; return 1; }
    done
    cw_java_sdk_shell || return 1
    sdk_installer=$(cw_fetch 'https://get.sdkman.io?rcupdate=false') || return 1
    printf '%s\n' "$sdk_installer" | "$sdk_shell" -n || return 1
    sdk_new_version=$(printf '%s\n' "$sdk_installer" | sed -nE 's/^export SDKMAN_VERSION="([0-9]+\.[0-9]+\.[0-9]+)"$/\1/p')
    [[ "$sdk_new_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    printf '%s\n' "$sdk_installer" | grep -Fq 'https://api.sdkman.io/2' || return 1
    cw_log INSTALL "SDKMAN! $sdk_new_version em $sdk_dir; instalador oficial HTTPS validado por formato/sintaxe, HOME temporário; aprovação específica necessária."
}
cw_java_sdk_install() (
    local work state=0
    cw_java_sdk_probe || state=$?
    [ "$state" -ne 0 ] || exit 0
    [ "$state" -eq 1 ] || exit 1
    cw_safe_destination "$sdk_dir" || exit 1
    work=$(mktemp -d) || exit 1
    trap 'rm -rf "$work"' EXIT
    mkdir "$work/home" || exit 1
    printf '%s\n' "$sdk_installer" > "$work/install.sh" || exit 1
    "$sdk_shell" -n "$work/install.sh" || exit 1
    # Even an upstream rcupdate regression cannot touch the real startup files.
    HOME="$work/home" ZDOTDIR="$work/home" SDKMAN_DIR="$sdk_dir" "$sdk_shell" "$work/install.sh" || exit 1
    cw_java_sdk_probe || exit 1
    [ "$sdk_version" = "$sdk_new_version" ] || exit 1
    # Only a NEW SDKMAN configuration is adjusted. Never rewrite a preexisting one.
    [ -f "$sdk_dir/etc/config" ] && [ ! -L "$sdk_dir/etc/config" ] || exit 1
    printf '\nsdkman_selfupdate_feature=false\nsdkman_auto_env=false\n' >> "$sdk_dir/etc/config" || exit 1
    cw_log OK "SDKMAN! $sdk_version instalado; arquivos de shell preservados."
)
cw_java_sdk_run() (
    # All loading and SDK calls happen after approval, in a separate Bash process.
    # Keep JAVA_HOME/PATH selected by the planner; sourcing SDKMAN must not pick another JDK.
    SDKMAN_DIR="$sdk_dir" "$sdk_shell" -c '
        set +eu
        saved_path=$PATH; saved_java=${JAVA_HOME-}; had_java=${JAVA_HOME+x}
        cd / || exit 1
        export SDKMAN_OFFLINE_MODE=true
        source "$SDKMAN_DIR/bin/sdkman-init.sh" || exit 1
        export PATH=$saved_path
        if [ "$had_java" = x ]; then export JAVA_HOME=$saved_java; else unset JAVA_HOME; fi
        [ "${SDKMAN_CANDIDATES_DIR:-$SDKMAN_DIR/candidates}" = "$SDKMAN_DIR/candidates" ] || exit 1
        export SDKMAN_CANDIDATES_API=https://api.sdkman.io/2
        export SDKMAN_BROKER_API=https://broker.sdkman.io
        export SDKMAN_OFFLINE_MODE=false
        sdkman_selfupdate_feature=false
        sdkman_auto_answer=false
        sdkman_auto_env=false
        sdkman_checksum_enable=true
        sdkman_insecure_ssl=false
        sdk version || exit 1
        sdk "$@"
    ' cw-sdk "$@"
)
cw_java_install_candidate() {
    local tool=$1 version=$2 state=0 cmd=$1 destination
    if [ "$tool" = java ]; then cw_java_probe || state=$?
    else cw_java_tool_probe "$tool" || state=$?; fi
    [ "$state" -ne 0 ] || { cw_log SKIP "$tool passou a estar funcional; preservado"; return 0; }
    case "$tool:$state" in java:1|java:3|maven:1|gradle:1) ;; *) return 1 ;; esac
    destination="$sdk_dir/candidates/$tool/$version"
    cw_safe_destination "$destination" || return 1
    [ ! -e "$destination" ] && [ ! -L "$destination" ] || { cw_log REVIEW "Destino existente preservado: $destination"; return 1; }
    # Never let SDKMAN replace an existing current/default, including a dangling link.
    [ ! -e "$sdk_dir/candidates/$tool/current" ] && [ ! -L "$sdk_dir/candidates/$tool/current" ] || {
        cw_log REVIEW "$tool possui seleção SDKMAN! existente; revise manualmente."; return 1;
    }
    cw_log PLAN "Instalar $tool $version e criar sua primeira seleção current no SDKMAN!; ativação no shell somente manual. Aprovar?"
    cw_confirm || return 3
    cw_java_sdk_run install "$tool" "$version" <<< 'n' || return 1
    case "$tool" in
        java)
            cw_java_pair "$destination/bin/java" "$destination/bin/javac" || return 1
            export JAVA_HOME="$destination"
            export PATH="$destination/bin:$PATH" ;;
        maven) cw_java_exec "$destination/bin/mvn" -version || return 1 ;;
        gradle) cw_java_exec "$destination/bin/gradle" --version || return 1 ;;
    esac
    cw_log OK "$tool $version validado em $destination"
}
