FROM --platform=$BUILDPLATFORM caddy:builder AS builder
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

FROM caddy:latest
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
