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
    if [ "$missing" -ne 0 ]; then
        echo "Non-standard modules in $tag:" >&2
        echo "$packages" >&2
    fi
    exit "$missing"
