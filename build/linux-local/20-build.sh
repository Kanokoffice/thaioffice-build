#!/bin/bash
# KanokOffice Linux release build (the .deb packages of release v26.8.1.1-kanok1): fresh tree from the upstream
# tarballs, the tag's patches/series + overlay + branding, the options of configure-linux.txt, full make.
# Runs as root in the container of 00-build-env.sh; configure and make run as BUILD_USER.
# usage: 20-build.sh <repo.tar>   repo.tar = git archive of the tag: git archive -o repo.tar v26.8.1.1-kanok1
# Layout (WORK, default /w): $WORK/src = libreoffice-26.8.1.1.tar.xz + libreoffice-translations-26.8.1.1.tar.xz,
# $WORK/out/ext-tar = the files of the release's external-sources tarball, $WORK/src-kanok1 = build dir
# (tree, branding, logs). Env: WORK, BUILD_USER (default b), BUILD_JOBS (default 8).
set -u
V=26.8.1.1; W=${WORK:-/w}; R=$W/src-kanok1; S=$R/libreoffice-$V; G=$R/repo; L=$R/logs
TAR=${1:?repo.tar}; U=${BUILD_USER:-b}; JOBS=${BUILD_JOBS:-8}
K=$(cd "$(dirname "$0")" && pwd)
mkdir -p $L
ts(){ date '+%F %T'; }
step(){ echo "[$(ts)] $*" | tee -a $L/steps.log; }
die(){ step "STOP: $*"; exit 1; }
step "start ($TAR)"
[ -e $S ] && die "$S exists"
# the tag, exported (not a working copy); made outside the container (git refuses a bind-mounted repo owned by another user)
mkdir -p $G && tar -x -C $G -f "$TAR" || die "repo.tar"
(cd $W/src && sha256sum -c --strict $G/build/upstream.sha256) > $L/upstream-sha.txt 2>&1 || die "upstream sha"
cd $R && tar -xJf $W/src/libreoffice-$V.tar.xz && tar -xJf $W/src/libreoffice-translations-$V.tar.xz || die "unpack"
cd $S
mkdir -p src/libreoffice-translations-$V
while read -r p; do
  [ -n "$p" ] || continue
  echo "== patch $p" >> $L/patch.log
  patch -p1 --no-backup-if-mismatch < $G/patches/$p >> $L/patch.log 2>&1 || die "patch $p"
done < $G/patches/series
step "patches applied: $(grep -c . $G/patches/series) · rej $(find . -name '*.rej' | wc -l)"
# --remove-destination: some overlay targets are symlinks upstream, a plain cp would write through them
cp -a --remove-destination $G/overlay/. . || die "overlay cp"
n=0; bad=0
while IFS= read -r -d '' f; do
  rel="${f#$G/overlay/}"; n=$((n+1))
  if [ -L "$rel" ] || ! cmp -s "$f" "$rel"; then echo "MISMATCH $rel" >> $L/overlay.log; bad=$((bad+1)); fi
done < <(find $G/overlay -type f -print0)
step "overlay files checked=$n mismatched=$bad"
[ "$bad" = 0 ] || die "overlay mismatch"
printf '%s\n' \
  '2936ea292bf2b82c572ed50837dc4a04170076b561bbfc5a9306037a989b470a  THSarabun.ttf' \
  '969fe7493a68f136dab33f51fabcbcaa44fe040582bec1a575e707f1850eb06c  THSarabun-Bold.ttf' \
  '9fd6e9672f5a78edf186591b8a9f376b8c27d0aac37875f818670a075995cec9  THSarabun-Italic.ttf' \
  'd52e0c8a058afc18f45c50b90f48de5954a46c0868ac826932ba5248b128ffc0  THSarabun-BoldItalic.ttf' \
  'f7a2fc4da4010c59c03df9dc17a8e44ff4860916a9a82f1bde8c929887821a31  DIP-SIPA-Font-License-Agreement.txt' \
  | (cd kanok/fonts && sha256sum -c --strict -) > $L/fonts-sha.txt 2>&1 || die "font sha"
rm -rf $R/branding && cp -a $G/branding $R/branding
chown -R $U:$U $R
mapfile -t opts < <(grep -v '^[[:space:]]*#' $K/configure-linux.txt | sed -e '/^[[:space:]]*$/d' \
  -e "s|@JOBS@|$JOBS|" -e "s|@EXT_TAR@|$W/out/ext-tar|" -e "s|@BRANDING@|$R/branding|")
printf 'option: %s\n' "${opts[@]}" > $L/configure-options.txt
step "configure"
q=$(printf '%q ' "${opts[@]}")
su $U -c "cd $S && ./autogen.sh $q" > $L/configure.log 2>&1 || die "configure rc=$?"
grep -E '^export (CCACHE|WITH_LANG|PRODUCTNAME|OOO_VENDOR|PARALLELISM|ENABLE_ONLINE_UPDATE|ENABLE_BREAKPAD)' config_host.mk > $L/config-key.txt
step "make -j$JOBS"
su $U -c "ccache -z >/dev/null; cd $S && CCACHE_MAXSIZE=15G /usr/bin/time -v make 2>&1" > $L/make.log 2>&1
rc=$?
su $U -c "ccache -s" > $L/ccache-stats.txt 2>&1
step "make rc=$rc"
find $S/workdir/installation -name '*.deb' > $L/debs.txt 2>/dev/null
step "debs $(wc -l < $L/debs.txt)"
step "done"
