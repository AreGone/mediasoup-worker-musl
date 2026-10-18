# mediasoup-worker-musl

Prebuilt [mediasoup](https://github.com/versatica/mediasoup) worker binaries
for **musl / Alpine Linux** (x64 and arm64), published as GitHub releases.

Upstream only ships glibc Linux, macOS and Windows prebuilds, so `npm install
mediasoup` inside an Alpine image compiles the C++ worker from source, which
takes 15 to 20 minutes on a CI runner. With this repository the install
downloads a ready binary instead.

## Use

Point mediasoup's postinstall at this repository before `npm ci` / `npm install`
(for example in a Dockerfile based on `node:<version>-alpine`):

```dockerfile
ENV MEDIASOUP_WORKER_PREBUILT_DOWNLOAD_BASE_URL=https://github.com/Netix-Offix/mediasoup-worker-musl/releases/download
RUN npm ci --foreground-scripts
```

mediasoup requests
`<base>/<mediasoup version>/mediasoup-worker-<version>-linux-<arch>-kernel<N>.tgz`,
runs the binary once to check that it works on the host, and falls back to
compiling from source when the file is missing or fails. Nothing else changes:
if a version has not been published here yet the build is only slower, not
broken. Keep the compiler packages in the image for that fallback.

## Releases

One release per mediasoup version, tagged with the exact npm version
(`3.19.21`, ...). Assets:

| asset | built on |
| --- | --- |
| `mediasoup-worker-<v>-linux-x64-kernel6.tgz` | `ubuntu-24.04`, inside `node:22-alpine` |
| `mediasoup-worker-<v>-linux-arm64-kernel6.tgz` | `ubuntu-24.04-arm`, inside `node:22-alpine` |
| `...-kernel5.tgz` | copies of the kernel6 files (mediasoup names the tarball after the kernel major version of the installing host; io_uring is probed at run time) |
| `SHA256SUMS` | checksums of the above |

The release notes carry the npm `dist.integrity` of the `mediasoup@<v>` package
the worker was compiled from.

## Workflow

`.github/workflows/build.yaml`:

- **schedule** (daily): resolves the latest `mediasoup` version on npm and
  builds it if no release exists yet.
- **workflow_dispatch**: `version` builds one specific version (what a consumer
  pins in its lockfile); `force` replaces an existing release.

Steps per architecture: compile in `node:22-alpine` with
`MEDIASOUP_SKIP_WORKER_PREBUILT_DOWNLOAD=1 npm install mediasoup@<v>`, pack with
mediasoup's own `npm run worker:prebuild` (so the layout matches upstream),
verify in a clean Alpine container (`scripts/verify.sh`: the worker must exit
41 when started without `MEDIASOUP_VERSION`), upload; the release job merges
both architectures, writes `SHA256SUMS` and creates the release with `gh`.

Nothing in this repository is a secret: the binaries are plain builds of an
open-source package, and the workflow only needs the default `GITHUB_TOKEN`
(`contents: write` in the release job).
