# Remote metadata stays in memory, including during dry-run. No SDK shell is loaded.
cw_java_sdk_platform() {
    case "$cw_os:$cw_arch" in
        ubuntu:x86_64) printf linuxx64 ;; ubuntu:aarch64|ubuntu:arm64) printf linuxarm64 ;;
        macos:x86_64) printf darwinx64 ;; macos:arm64|macos:aarch64) printf darwinarm64 ;;
        *) return 1 ;;
    esac
}
cw_java_catalog() {
    local platform
    platform=$(cw_java_sdk_platform) || return 1
    cw_fetch "https://api.sdkman.io/2/candidates/$1/$platform/versions/list?current=&installed="
}
cw_java_lts() {
    local metadata major catalog
    metadata=$(cw_fetch https://api.adoptium.net/v3/info/available_releases) || return 1
    major=$(printf '%s' "$metadata" | tr '\n' ' ' | sed -nE 's/.*"most_recent_lts"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p')
    [[ "$major" =~ ^[0-9]+$ ]] || return 1
    # Confirm the same major is explicitly advertised as LTS, not just a feature release.
    printf '%s' "$metadata" | tr '\n' ' ' | sed -nE 's/.*"available_lts_releases"[[:space:]]*:[[:space:]]*\[([^]]*)\].*/\1/p' |
        tr ', ' '\n' | grep -qx "$major" || return 1
    catalog=$(cw_java_catalog java) || return 1
    java_candidate=$(printf '%s\n' "$catalog" | awk -F '|' -v major="$major" '
        {id=$NF; gsub(/[[:space:]]/,"",id); if(id ~ /^[0-9]+\.[0-9]+\.[0-9]+-tem$/) {
            split(id,v,"."); if(v[1]==major) print id
        }}' | sort -t. -k1,1nr -k2,2nr -k3,3nr | head -n 1)
    [ -n "$java_candidate" ] || return 1
    java_target_major=$major
}
cw_java_stable() {
    tr ' |\t' '\n' | grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)?$' |
        sort -t. -k1,1nr -k2,2nr -k3,3nr | head -n 1
}
cw_java_build_version() {
    local tool=$1 major=$2 catalog version html bounds low high
    catalog=$(cw_java_catalog "$tool") || return 1
    version=$(printf '%s\n' "$catalog" | cw_java_stable)
    [ -n "$version" ] || return 1
    case "$tool" in
        maven)
            # Conservative supported Maven 3 lines; unknown future requirements fail closed.
            case "$version" in 3.9.*|3.10.*) [ "$major" -ge 8 ] || return 1 ;; *) return 1 ;; esac ;;
        gradle)
            # Use the selected release's documentation, not an unversioned compatibility guess.
            html=$(cw_fetch "https://docs.gradle.org/$version/userguide/compatibility.html") || return 1
            bounds=$(printf '%s' "$html" | tr '\n' ' ' | sed -E 's/<[^>]*>/ /g; s/[[:space:]]+/ /g' |
                sed -nE 's/.*JVM version between ([0-9]+) and ([0-9]+) is required to execute Gradle.*/\1 \2/p')
            low=${bounds%% *}; high=${bounds##* }
            [[ "$low" =~ ^[0-9]+$ ]] && [[ "$high" =~ ^[0-9]+$ ]] || return 1
            [ "$major" -ge "$low" ] && [ "$major" -le "$high" ] || return 1 ;;
        *) return 1 ;;
    esac
    printf '%s\n' "$version"
}
