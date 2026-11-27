default:
    @just --list

# Run code linting tools without modifying files.
lint:
    GH_TOKEN="$(gh auth token)" zizmor --persona auditor .

# Run all prek hooks on all files.
prek:
    prek run --all-files

# Build an image, e.g. `just build "github.com/caddy-dns/cloudflare github.com/mholt/caddy-l4" 2.11.9`.
build $modules $caddy_version="2" $tag="caddy-images:dev":
    docker build --pull --build-arg CADDY_MODULES="$modules" --build-arg CADDY_VERSION="$caddy_version" --tag "$tag" .

# Check that a built image runs the given Caddy version and contains the given modules, e.g. `just test "github.com/caddy-dns/cloudflare github.com/mholt/caddy-l4" 2.11.9`.
test $modules $caddy_version="2" $tag="caddy-images:dev":
    #!/usr/bin/env bash
    set -euo pipefail
    version=$(docker run --rm --network none "$tag" caddy version)
    echo "$version"
    # Matches the exact version (2.11.9) as well as a prefix (2.11 or 2).
    case "$version" in
        "v$caddy_version "* | "v$caddy_version."*) ;;
        *) echo "error: expected Caddy $caddy_version" >&2; exit 1 ;;
    esac
    packages=$(docker run --rm --network none "$tag" caddy list-modules --packages --skip-standard)
    # Empty if the folder doesn't exist, so each missing license is reported below.
    licenses=$(docker run --rm --network none "$tag" find /usr/share/licenses/caddy -type f 2>/dev/null || true)
    missing=0
    for module in $modules; do
        # A module may be given as path@version, and its packages may be below its path.
        path="${module%%@*}"
        if awk -v m="$path" '$2 == m || index($2, m "/") == 1 { found = 1 } END { exit !found }' <<< "$packages"; then
            echo "ok: $path"
        else
            echo "error: module $path is missing" >&2
            missing=1
        fi
    done
    for path in go github.com/caddyserver/caddy/v2 $modules; do
        path="${path%%@*}"
        if grep -q "^/usr/share/licenses/caddy/$path/" <<< "$licenses"; then
            echo "ok: license of $path"
        else
            echo "error: license of $path is missing" >&2
            missing=1
        fi
    done
    if [ "$missing" -ne 0 ]; then
        echo "Non-standard modules in $tag:" >&2
        echo "$packages" >&2
    fi
    exit "$missing"

# Pin modules to the versions xcaddy would pick, e.g. `just resolve-modules "github.com/caddy-dns/cloudflare github.com/mholt/caddy-l4"`.
resolve-modules $modules:
    #!/usr/bin/env bash
    set -euo pipefail
    resolved=()
    for module in $modules; do
        path="${module%%@*}"
        # The module proxy expects upper-case letters as "!" plus the lower-case letter.
        encoded=$(sed 's/[A-Z]/!\L&/g' <<< "$path")
        if [[ "$module" == *@* ]]; then
            url="https://proxy.golang.org/$encoded/@v/${module#*@}.info"
        else
            url="https://proxy.golang.org/$encoded/@latest"
        fi
        version=$(curl -fsSL "$url" | jq -r '.Version')
        resolved+=("$path@$version")
    done
    echo "${resolved[*]}"

# Print everything a build depends on, for pinned modules and an exact Caddy version.
build-inputs $modules $caddy_version:
    #!/usr/bin/env bash
    set -euo pipefail
    # Only the platforms we publish, so updates of other platforms (e.g. Windows) don't count.
    index=$(docker buildx imagetools inspect "caddy:$caddy_version" --raw)
    inputs=("caddy=$caddy_version")
    for platform in linux/amd64 linux/arm64; do
        digest=$(jq -r --arg os "${platform%/*}" --arg arch "${platform#*/}" \
            '.manifests[] | select(.platform.os == $os and .platform.architecture == $arch) | .digest' <<< "$index")
        [ -n "$digest" ] || { echo "error: caddy:$caddy_version has no $platform image" >&2; exit 1; }
        inputs+=("caddy-$platform=$digest")
    done
    # The binary is cross-compiled on amd64, so only the builder's Go version matters, not its other contents.
    go=$(docker buildx imagetools inspect "caddy:$caddy_version-builder" --format '{{{{json .Image}}' |
        jq -r '."linux/amd64".config.Env[] | select(startswith("GOLANG_VERSION=")) | ltrimstr("GOLANG_VERSION=")')
    [ -n "$go" ] || { echo "error: caddy:$caddy_version-builder has no GOLANG_VERSION" >&2; exit 1; }
    inputs+=("go=$go" $modules)
    echo "${inputs[*]}"
