default:
    @just --list

# Run code linting tools without modifying files.
lint:
    GH_TOKEN="$(gh auth token)" zizmor --persona auditor .

# Run all prek hooks on all files.
prek:
    prek run --all-files

# Build an image, e.g. `just build "github.com/caddy-dns/cloudflare github.com/mholt/caddy-l4"`.
build $modules $tag="caddy-images:dev":
    docker build --pull --build-arg CADDY_MODULES="$modules" --tag "$tag" .

# Check that a built image runs and contains the given modules, e.g. `just test "github.com/caddy-dns/cloudflare github.com/mholt/caddy-l4"`.
test $modules $tag="caddy-images:dev":
    #!/usr/bin/env bash
    set -euo pipefail
    docker run --rm --network none "$tag" caddy version
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
