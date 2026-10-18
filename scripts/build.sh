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
# runs npm install. Publish the same build under the kernel5 name too so hosts
# on a 5.x kernel (older LTS distributions) get it as well; io_uring support is
# probed at run time by the worker.
for f in "$out"/*-kernel6.tgz; do
  cp "$f" "${f%-kernel6.tgz}-kernel5.tgz"
done
ls -la "$out"
