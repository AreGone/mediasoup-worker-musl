#!/usr/bin/env bash
# Extract every tarball in <out dir> inside a clean Alpine node image and run
# the worker. Without MEDIASOUP_VERSION the worker exits with code 41 on
# purpose; mediasoup's own postinstall uses the same check to prove that a
# downloaded binary links and runs on the host.
#   scripts/verify.sh <out dir>
set -euo pipefail

out=${1:?output directory}
: "${NODE_IMAGE:?NODE_IMAGE (Alpine node image) must be set}"

for tgz in "$out"/*.tgz; do
  name=$(basename "$tgz")
  echo "== $name"
  docker run --rm -v "$out:/out:ro" -e NAME="$name" "$NODE_IMAGE" sh -euc '
    apk add --no-cache libstdc++ >/dev/null
    mkdir -p /t && cd /t && tar xzf "/out/$NAME"
    test -f mediasoup-worker
    chmod +x mediasoup-worker
    echo "-- linked libraries"; ldd ./mediasoup-worker
    set +e; env -i ./mediasoup-worker; rc=$?; set -e
    if [ "$rc" != 41 ]; then echo "unexpected exit code $rc (expected 41)" >&2; exit 1; fi
    echo "-- runs on musl (exit 41 as expected)"
  '
done
