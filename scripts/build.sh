#!/usr/bin/env bash
# Compile the mediasoup worker of the given version inside the Alpine node
# image and leave the prebuilt tarballs in <out dir>.
#   scripts/build.sh <mediasoup version> <out dir>
# Env: NODE_IMAGE (Alpine-based node image; the consumers' base image).
set -euo pipefail

version=${1:?mediasoup version}
out=${2:?output directory}
: "${NODE_IMAGE:?NODE_IMAGE (Alpine node image) must be set}"
mkdir -p "$out"

docker run --rm -v "$out:/out" -e VERSION="$version" "$NODE_IMAGE" sh -euxc '
  # Native toolchain mediasoup needs (meson/ninja come through pip).
  apk add --no-cache python3 py3-pip make g++ linux-headers
  # Node headers ship with the image; no nodejs.org download for node-gyp.
  export npm_config_nodedir=/usr/local
  mkdir -p /build && cd /build && npm init -y >/dev/null
  # Skip the (glibc) prebuilt download so the worker is compiled here, against musl.
  MEDIASOUP_SKIP_WORKER_PREBUILT_DOWNLOAD=1 \
    npm install --foreground-scripts --no-audit --no-fund "mediasoup@$VERSION"
  cd node_modules/mediasoup
  # Packs worker/out/Release/mediasoup-worker as mediasoup-worker-<ver>-linux-<arch>-kernel<N>.tgz
  npm run worker:prebuild
  ls -la worker/prebuild
  cp worker/prebuild/*.tgz /out/
'

# mediasoup names the tarball after the kernel major version of the host that
# runs npm install (GitHub runners: 6; Docker Desktop: 7; older LTS servers: 5),
# so publish the same build under every name a consumer may request. The
# worker probes io_uring support at run time, the build itself is identical.
for f in "$out"/*-kernel*.tgz; do
  base=${f%-kernel*.tgz}
  for k in 5 6 7; do
    [ -e "$base-kernel$k.tgz" ] || cp "$f" "$base-kernel$k.tgz"
  done
done
ls -la "$out"
