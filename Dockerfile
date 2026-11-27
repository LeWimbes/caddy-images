# Caddy version to build, e.g. 2.11.9.
# CI passes the exact version, the default builds the latest Caddy 2.
ARG CADDY_VERSION=2

FROM --platform=$BUILDPLATFORM caddy:${CADDY_VERSION}-builder AS builder
ARG TARGETOS
ARG TARGETARCH
# Space-separated Go module paths to build into Caddy, e.g.
# "github.com/caddy-dns/cloudflare github.com/mholt/caddy-l4"
ARG CADDY_MODULES
RUN set -eu; \
    [ -n "${CADDY_MODULES:-}" ] || { echo "error: build arg CADDY_MODULES is required" >&2; exit 1; }; \
    set --; \
    for module in ${CADDY_MODULES}; do set -- "$@" --with "${module}"; done; \
    GOOS=${TARGETOS} GOARCH=${TARGETARCH} xcaddy build "$@"

# Collect the license files of Go and of every module in the binary,
# since most of their licenses require them to be distributed with it.
# The module list comes from the binary itself,
# and their sources from xcaddy's build folder.
SHELL ["/bin/ash", "-euo", "pipefail", "-c"]
RUN buildenv=$(ls -d /tmp/buildenv_*); \
    mkdir -p /licenses/go; \
    cp "$(go env GOROOT)/LICENSE" /licenses/go/; \
    go version -m /usr/bin/caddy | awk '$1 == "dep" { print $2 }' | \
        xargs go list -C "${buildenv}" -m -f '{{.Path}} {{.Dir}}' | \
    while read -r path dir; do \
        mkdir -p "/licenses/${path}"; \
        find "${dir}" -maxdepth 1 -type f \( -iname 'LICEN[CS]E*' -o -iname 'COPYING*' -o -iname 'NOTICE*' \) \
            -exec cp {} "/licenses/${path}/" \; ; \
        [ -n "$(ls -A "/licenses/${path}")" ] || { echo "error: no license file found for ${path}" >&2; exit 1; }; \
    done

FROM caddy:${CADDY_VERSION}
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
COPY --from=builder /licenses /usr/share/licenses/caddy
