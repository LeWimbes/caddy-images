# Caddy images with modules

[![Build status](https://github.com/lewimbes/caddy-images/actions/workflows/auto-build-on-change.yml/badge.svg)](https://github.com/lewimbes/caddy-images/actions/workflows/auto-build-on-change.yml)

Automatically builds and publishes **multi‑architecture Docker images** for [Caddy](https://caddyserver.com) with modules pre‑installed.

| Image                          | Included modules                                                                                                         |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| `lewimbes/caddy-cloudflare`    | [`caddy-dns/cloudflare`](https://github.com/caddy-dns/cloudflare)                                                        |
| `lewimbes/caddy-cloudflare-l4` | [`caddy-dns/cloudflare`](https://github.com/caddy-dns/cloudflare), [`mholt/caddy-l4`](https://github.com/mholt/caddy-l4) |

---

## ✨ Why use these images?

- **Cloudflare DNS provider built-in** – use `tls.dns.cloudflare`, ACME DNS challenges, or ECH without rebuilding Caddy.
- **Layer 4 App built-in** (`-l4` image) – handle raw TCP & UDP connections.
- **Multi‑arch** – runs on `linux/amd64` and `linux/arm64`.
- **Automatic rebuilds** – whenever Caddy, its base image, Go or a module has an update.
- Available from **Docker Hub** (`lewimbes/<image>`) and **GHCR** (`ghcr.io/lewimbes/<image>`).

---

## 📦 Quick start

```bash
# Pull the latest image
docker pull lewimbes/caddy-cloudflare:latest

# Or pin a specific version
docker pull lewimbes/caddy-cloudflare:2.11.9
docker pull lewimbes/caddy-cloudflare:2.11
docker pull lewimbes/caddy-cloudflare:2
```

Replace `caddy-cloudflare` with `caddy-cloudflare-l4` for the image with the Layer 4 app.

---

## 🏷️ Tags

| Tags                                                | Example                         | Points to                          |
| --------------------------------------------------- | ------------------------------- | ---------------------------------- |
| `latest`, `<major>`, `<major>.<minor>`, `<version>` | `latest`, `2`, `2.11`, `2.11.9` | The newest build, moves on rebuild |
| `<version>-<YYYYMMDD>.<HHMM>` (UTC)                 | `2.11.9-20261126.0420`          | One build, never moves             |

Images are also rebuilt without a new Caddy version, e.g. for a new module release or Go version.
To stay on a known-good build or roll back to one, use its date-suffixed tag:

```bash
docker pull lewimbes/caddy-cloudflare:2.11.9-20261126.0420
```

To see what a build contains, read its `build-inputs` label:

```bash
docker buildx imagetools inspect lewimbes/caddy-cloudflare:latest --format '{{json .Image}}' \
  | jq -r '."linux/amd64".config.Labels["io.github.lewimbes.caddy-images.build-inputs"]'
```

---

## 🛠️ Build it yourself

The modules to build into Caddy are passed as a space-separated list.
The Caddy version is optional and defaults to the latest Caddy 2.
With [just](https://github.com/casey/just), this builds an image for your platform and tests it, like the workflow does:

```bash
just build "github.com/caddy-dns/cloudflare github.com/mholt/caddy-l4" 2.11.9
just test "github.com/caddy-dns/cloudflare github.com/mholt/caddy-l4" 2.11.9
```

Without just, the build is a plain Docker build:

```bash
docker build \
  --build-arg CADDY_MODULES="github.com/caddy-dns/cloudflare github.com/mholt/caddy-l4" \
  --build-arg CADDY_VERSION=2.11.9 \
  --tag caddy-images:dev .
```

---

## 🤖 How the workflow works

[`auto-build-on-change.yml`](./.github/workflows/auto-build-on-change.yml) lists the images and their modules.
It reads the Caddy version from `caddy:latest` once, so all images are built from the same version,
and runs [`build-image.yml`](./.github/workflows/build-image.yml) for each image:

- **Triggers**
  - Any push to the `main` branch that changes the Dockerfile, the justfile or the workflows
  - A daily scheduled run that checks whether the Caddy version, the `caddy` base image, the Go version or a module
    has changed since the published image was built (recorded in its `io.github.lewimbes.caddy-images.build-inputs` label)
  - A manual run
  - Pull requests with such changes, which only build and test the image

- **If an update is needed**, the workflow:
  - builds the image natively on linux/amd64 and linux/arm64 and
    checks that it runs the expected Caddy version and contains its modules
    (`just build` and `just test`, which also work locally),
  - builds Caddy with the image's modules, pinned to their latest versions, for linux/amd64 and linux/arm64,
  - tags the result (latest, full semver, major‑minor, major),
  - pushes to **Docker Hub** and **GHCR**.

Each image is checked, tested and built independently, so a module that fails to build does not hold back the others.

---

## 📝 License

This repository is licensed under the **Apache License 2.0**.  
[Caddy](https://github.com/caddyserver/caddy), [Caddy-Docker](https://github.com/caddyserver/caddy-docker), the [Cloudflare DNS provider](https://github.com/caddy-dns/cloudflare) and [Layer 4 App](https://github.com/mholt/caddy-l4) are upstream Apache‑2.0 projects.

---

### Official resources

- Upstream project – <https://caddyserver.com>
- Official Docker image – <https://hub.docker.com/_/caddy>
