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

FROM caddy:${CADDY_VERSION}
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
