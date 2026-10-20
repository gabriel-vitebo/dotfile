# Java probes: 0 functional, 1 absent, 2 review, 3 runtime only.
cw_java_major() {
    sed -nE 's/.*version "([0-9]+)(\.([0-9]+))?.*/\1 \3/p; s/^javac ([0-9]+)(\.([0-9]+))?.*/\1 \3/p' |
        awk 'NR==1 {if ($1==1) print $2; else print $1}'
}
cw_java_origin() {
    local path=$1 resolved=$1 link count=0
    while [ -L "$resolved" ] && [ "$count" -lt 20 ]; do
        link=$(readlink "$resolved") || break
        case "$link" in /*) resolved=$link ;; *) resolved="${resolved%/*}/$link" ;; esac
        count=$((count + 1))
    done
    case "$resolved" in
        "${SDKMAN_DIR:-$HOME/.sdkman}"/*) printf 'SDKMAN!' ;;
        *Cellar/*|*homebrew/*|*/opt/openjdk/*) printf Homebrew ;;
        /usr/lib/jvm/*|/usr/bin/*) printf sistema ;;
        /Library/Java/*|"$HOME/Library/Java/"*) printf 'JDK registrado no macOS' ;;
        *) printf 'externa/origem não identificada' ;;
    esac
    printf ' (%s)' "$resolved"
}
cw_java_exec() {
    # Never run Maven in a project (mvn.config/extensions) or run a Gradle build.
    (cd / && "$@")
}
cw_java_pair() {
    local runtime compiler
    runtime=$(cw_java_exec "$1" -version 2>&1) || return 2
    compiler=$(cw_java_exec "$2" -version 2>&1) || return 3
    java_major=$(printf '%s\n' "$runtime" | cw_java_major)
    [ -n "$java_major" ] && [ "$java_major" = "$(printf '%s\n' "$compiler" | cw_java_major)" ] || return 2
    java_version=$(printf '%s\n' "$runtime" | sed -n '/version "/p' | head -n 1)
    java_bin=$1
    javac_bin=$2
}
cw_java_probe() {
    local jp cp dir state=0 found=0
    java_version=; java_major=; java_bin=; javac_bin=
    jp=$(command -v java || true); cp=$(command -v javac || true)
    if [ -n "$jp" ]; then
        # Apple's /usr/bin/java and javac are launchers, not proof of an installed JDK.
        if [ "${cw_os:-}" = macos ] && [ "$jp" = /usr/bin/java ]; then
            dir=$(/usr/libexec/java_home 2>/dev/null) || dir=
            if [ -n "$dir" ]; then cw_java_pair "$dir/bin/java" "$dir/bin/javac"; return $?; fi
        else
            cw_java_pair "$jp" "${cp:-/nonexistent/javac}" || state=$?
            return "$state"
        fi
    elif [ -n "$cp" ]; then return 2; fi
    for dir in "${JAVA_HOME:-}" "${SDKMAN_DIR:-$HOME/.sdkman}"/candidates/java/* \
        /usr/lib/jvm/* /Library/Java/JavaVirtualMachines/*/Contents/Home \
        "$HOME"/Library/Java/JavaVirtualMachines/*/Contents/Home \
        /opt/homebrew/opt/openjdk*/libexec/openjdk.jdk/Contents/Home \
        /usr/local/opt/openjdk*/libexec/openjdk.jdk/Contents/Home; do
        [ -d "$dir" ] || continue
        found=1
        if cw_java_pair "$dir/bin/java" "$dir/bin/javac"; then return 0; fi
    done
    [ "$found" -eq 0 ] || return 2
    return 1
}
cw_java_tool_probe() {
    local tool=$1 cmd=$1 option=-version dir path
    cw_version=; cw_tool_path=
    case "$tool" in maven) cmd=mvn ;; gradle) option=--version ;; esac
    path=$(command -v "$cmd" || true)
    if [ -z "$path" ]; then
        for dir in "${SDKMAN_DIR:-$HOME/.sdkman}/candidates/$tool/"* \
            "/opt/homebrew/opt/$tool" "/usr/local/opt/$tool" "/usr/share/$tool"; do
            [ -d "$dir" ] || continue
            if [ -x "$dir/bin/$cmd" ]; then path="$dir/bin/$cmd"; break; fi
            return 2
        done
    fi
    [ -n "$path" ] || return 1
    cw_tool_path=$path
    # Disable native cache extraction for a read-only Gradle version probe.
    cw_version=$(GRADLE_OPTS="${GRADLE_OPTS:-} -Dorg.gradle.native=false -Dorg.gradle.vfs.watch=false" cw_java_exec "$path" "$option" 2>&1) || return 2
    [ -n "$cw_version" ] || return 2
    # Report the version banner, not JVM option/environment diagnostics.
    local banner
    banner=$(printf '%s\n' "$cw_version" | sed -nE '/(Apache Maven|Gradle) [0-9]/p' | head -n 1)
    [ -z "$banner" ] || cw_version=$banner
}
cw_java_home_check() {
    local version major
    [ -n "${JAVA_HOME:-}" ] || return 0
    cw_log SKIP 'JAVA_HOME existente preservado (nenhuma edição de variável ou shell).'
    version=$(cw_java_exec "$JAVA_HOME/bin/java" -version 2>&1) || return 1
    major=$(printf '%s\n' "$version" | cw_java_major)
    [ -n "$major" ] && [ "$major" = "$java_major" ] && [ -x "$JAVA_HOME/bin/javac" ]
}
