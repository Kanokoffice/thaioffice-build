#!/bin/bash
# KanokOffice local Windows build (Cygwin bash): the "Unpack, patch, overlay" and "Configure" steps are
# copied verbatim from .github/workflows/windows-msi.yml (generated, do not edit); only the inputs differ:
# upstream tarballs come from C:\lo\in (checked against build/upstream.sha256 as in the workflow) and
# make runs without the GitHub job-time budget. Parallelism: BUILD_JOBS (default 6).
# usage: 20-build.sh <commit>   (run as: C:\cygwin64\bin\bash.exe -o igncr -eo pipefail /cygdrive/c/lo/kit/20-build.sh b7f53e1)
set -eo pipefail
export PATH="/opt/lo/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
commit="${1:?commit}"
export LO_VERSION=26.8.1.1 LO_ROOT='C:\lo' BUILD_JOBS="${BUILD_JOBS:-6}" CCACHE_DIR='C:\lo\ccache' CCACHE_MAXSIZE=20G
# MSI packaging: expand.exe cannot write into Cygwin-ACL dirs under C:\cygwin64\tmp ("Access is denied", local
# build 26 Oct); a temp dir created on C:\lo works. configure copies TMPDIR into config_host.mk.
mkdir -p /cygdrive/c/lo/tmp; export TMPDIR=C:/lo/tmp TMP=C:/lo/tmp TEMP=C:/lo/tmp
export GITHUB_WORKSPACE='C:\lo\repo' GITHUB_ENV=/cygdrive/c/lo/logs/env.txt HOME=/home/builder
: > "$GITHUB_ENV"
log() { echo "$(date +%H:%M:%S) $*" | tee -a /cygdrive/c/lo/logs/20-build-steps.log; }
root=/cygdrive/c/lo
mkdir -p "$root/diag" "$root/tarballs" "$root/dl" "$root/out" "$root/ccache"
log "repo checkout $commit"
[ -d "$root/repo/.git" ] || git clone -q https://github.com/Kanokoffice/thaioffice-build.git "$root/repo"
git -C "$root/repo" -c core.autocrlf=false fetch -q origin
git -C "$root/repo" -c core.autocrlf=false checkout -q --force "$commit"
git -C "$root/repo" log -1 --format='repo at %H %an <%ae> %s' | tee -a /cygdrive/c/lo/logs/20-build-steps.log
log "inputs"
cp -n "$root"/in/ext/* "$root/tarballs/" 2>/dev/null || true
echo "external tarballs: $(ls "$root/tarballs" | wc -l)"
if [ "${REUSE_TREE:-0}" = 1 ] && [ -f "$root/libreoffice-$LO_VERSION/autogen.sh" ]; then
  log "REUSE_TREE=1: keeping the unpacked, patched tree"
else
rm -rf "$root/libreoffice-$LO_VERSION"
(cd "$root/dl" && cp "$root"/in/libreoffice-$LO_VERSION.tar.xz "$root"/in/libreoffice-translations-$LO_VERSION.tar.xz . && sha256sum -c "$(cygpath -u "$GITHUB_WORKSPACE")/build/upstream.sha256")
log "step: Unpack, patch, overlay (workflow)"
( set -eo pipefail
export PATH="/opt/lo/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
ws="$(cygpath -u "$GITHUB_WORKSPACE")"
root="$(cygpath -u "$LO_ROOT")"
cd "$root"
tar -xJf dl/libreoffice-$LO_VERSION.tar.xz
tar -xJf dl/libreoffice-translations-$LO_VERSION.tar.xz
rm -rf dl
cd "libreoffice-$LO_VERSION"
# translations are already unpacked into translations/ (our patches edit them). Without this
# directory, make's get-submodules re-downloads the tarball and Cygwin tar fails on the C:/ path.
mkdir -p "src/libreoffice-translations-$LO_VERSION"
while read -r p; do
  [ -n "$p" ] || continue
  echo "== patch $p"
  patch -p1 --no-backup-if-mismatch < "$ws/patches/$p"
done < "$ws/patches/series"
# Windows edition of the notices (kanok-v1-license.diff): make-notices.py --windows leaves @BUILD_DATE@
tpn=readlicense_oo/license/THIRD-PARTY-NOTICES-windows
sed -i "s/@BUILD_DATE@/$(date -u +%Y-%m-%d)/" "$tpn"
if grep -q '@BUILD_DATE@' "$tpn" || ! grep -q 'Windows Installer package for x86-64, built 20' "$tpn"; then
  echo "THIRD-PARTY-NOTICES-windows: build date not filled in"; exit 1
fi
grep -m1 'Windows Installer package' "$tpn"
# 54 overlay targets are symlinks upstream: replace the link, do not write through it.
# -R, not -a: Cygwin cannot preserve NTFS directory permissions here (run 39928738011 failed on that)
cp -R --remove-destination "$ws/overlay/." .
n=0; bad=0
while IFS= read -r -d '' f; do
  rel="${f#$ws/overlay/}"; n=$((n+1))
  if [ -L "$rel" ] || ! cmp -s "$f" "$rel"; then echo "MISMATCH $rel"; bad=$((bad+1)); fi
done < <(find "$ws/overlay" -type f -print0)
echo "overlay files checked=$n mismatched=$bad"
[ "$bad" = 0 ]
# TH SarabunPSK (module kanok): the files as received, byte for byte (DIP & SIPA license terms 2-3, legal review §15.20)
printf '%s\n' \
  '2936ea292bf2b82c572ed50837dc4a04170076b561bbfc5a9306037a989b470a  THSarabun.ttf' \
  '969fe7493a68f136dab33f51fabcbcaa44fe040582bec1a575e707f1850eb06c  THSarabun-Bold.ttf' \
  '9fd6e9672f5a78edf186591b8a9f376b8c27d0aac37875f818670a075995cec9  THSarabun-Italic.ttf' \
  'd52e0c8a058afc18f45c50b90f48de5954a46c0868ac826932ba5248b128ffc0  THSarabun-BoldItalic.ttf' \
  'f7a2fc4da4010c59c03df9dc17a8e44ff4860916a9a82f1bde8c929887821a31  DIP-SIPA-Font-License-Agreement.txt' \
  | (cd kanok/fonts && sha256sum -c --strict -)
echo "symlinks left in tree: $(find . -type l | wc -l)"; find . -type l
rm -rf "$root/branding"; cp -R "$ws/branding" "$root/branding"
)
fi
log "step: Configure (workflow)"
( set -eo pipefail
set -a; . "$GITHUB_ENV"; set +a
export PATH="/opt/lo/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
ws="$(cygpath -u "$GITHUB_WORKSPACE")"
root="$(cygpath -u "$LO_ROOT")"
ext="$(cygpath -m "$LO_ROOT")/tarballs"
brand="$(cygpath -m "$LO_ROOT")/branding"
mapfile -t opts < <(grep -v '^[[:space:]]*#' "$ws/build/configure-windows.txt" | sed -e '/^[[:space:]]*$/d' \
  -e "s|@EXT_TAR@|$ext|" -e "s|@BRANDING@|$brand|")
opts+=("--with-parallelism=$BUILD_JOBS")
printf 'option: %s\n' "${opts[@]}"
cd "$root/libreoffice-$LO_VERSION"
mkdir -p "$HOME"
./autogen.sh "${opts[@]}"
grep -E '^export (CCACHE|ENABLE_CLI|WITH_LANG|PRODUCTNAME|OOO_VENDOR|ENABLE_PCH)=' config_host.mk || true
/opt/lo/bin/ccache.exe -s || true
echo "CONFIGURED_AT=$(date +%s)" >> "$(cygpath -u "$GITHUB_ENV")"
)
log "step: make -j$BUILD_JOBS build"
set -a; . "$GITHUB_ENV"; set +a
cd "$root/libreoffice-$LO_VERSION"
rc=0
/opt/lo/bin/make.exe -j$BUILD_JOBS build TMPDIR=C:/lo/tmp TMP=C:/lo/tmp > "$root/diag/make.log" 2>&1 || rc=$?
log "make rc=$rc elapsed=$(( ($(date +%s) - CONFIGURED_AT) / 60 )) min"
tail -n 60 "$root/diag/make.log"
/opt/lo/bin/ccache.exe -s -v > "$root/diag/ccache-stats.txt" 2>&1 || true
exit $rc
