#!/bin/bash
# Runs 40-test-deb.sh in a clean container without network: the image is test-base/Dockerfile.<system> (the
# system + the libraries the office links to + the test tools, no KanokOffice); the tarball and the test files
# are mounted read-only. usage: 41-run-test.sh <tar.gz> <system> <out dir>   system = ubuntu-24.04 | debian-12 |
# ubuntu-26.04. Env DOCKER_RUN_OPTS: extra options for docker build and docker run (e.g. labels).
set -eu
TGZ=$(realpath "$1"); SYS=$2; mkdir -p "$3"; OUT=$(realpath "$3")
K=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$K/../.." && pwd)
IMG=kanok-deb-test-base:$SYS
docker build -q ${DOCKER_RUN_OPTS:-} -t $IMG -f "$K/test-base/Dockerfile.$SYS" "$K/test-base" > /dev/null
X=$(mktemp -d); trap 'rm -rf "$X"' EXIT
mkdir -p "$X/expect"
cp "$K/40-test-deb.sh" "$REPO/build/check-install.py" "$REPO/build/windows-local/gui-client.py" "$X/"
cp "$K/expect/about-en.txt" "$K/expect/about-th.txt" "$REPO/overlay/readlicense_oo/license/KANOK-NOTICE.txt" "$X/expect/"
chmod -R a+rX "$X"
set +e
docker run --rm --network none ${DOCKER_RUN_OPTS:-} -v "$X:/t:ro" -v "$TGZ:/in/$(basename "$TGZ"):ro" -v "$OUT:/out" \
  $IMG bash /t/40-test-deb.sh "/in/$(basename "$TGZ")" /out
rc=$?
echo "rc=$rc ($SYS) · results in $OUT"
exit $rc
