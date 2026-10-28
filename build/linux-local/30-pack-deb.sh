#!/bin/bash
# KanokOffice .deb release tarball: the main product's DEBS + the Thai language pack's DEBS in one DEBS/ folder,
# the install README (README-package.txt, Thai + English) and KANOK-NOTICE.txt. Reproducible (sorted names,
# owner 0, fixed mtime, gzip -n). The upstream readmes/README_en-US is left out: it is LibreOffice's text and
# states requirements (glibc 2.27) this build does not meet.
# kanokbasis26.8-librelogo is left out too: with the system Python, scp2/InstallModule_python.mk does not pass
# ENABLE_LIBRELOGO, so the pyuno package gets packinfo_librelogo_disabled.txt (Conflicts/Replaces librelogo) while
# the librelogo package is still made; with both in DEBS/, apt refuses the install (LibreLogo is optional).
# usage: 30-pack-deb.sh <source tree> <README-package.txt> <overlay/readlicense_oo/license/KANOK-NOTICE.txt> <out dir>
set -eu
S=$1; README=$2; NOTICE=$3; OUT=$4
N=KanokOffice_26.8.1.1_Linux_x86-64_deb_th
I=$S/workdir/installation
MAIN=$I/KanokOffice/deb/install/KanokOffice_26.8.1.1_Linux_x86-64_deb/DEBS
LANG_TH=$I/KanokOffice_languagepack/deb/install/KanokOffice_26.8.1.1_Linux_x86-64_deb_langpack_th/DEBS
W=$(mktemp -d); trap 'rm -rf $W' EXIT
mkdir -p $W/$N/DEBS $OUT
cp -p $MAIN/*.deb $LANG_TH/*.deb $W/$N/DEBS/
rm $W/$N/DEBS/kanokbasis26.8-librelogo_*.deb
dpkg-deb -f $W/$N/DEBS/kanokbasis26.8-pyuno_*.deb Conflicts | grep -q librelogo || { echo "pyuno no longer conflicts with librelogo: keep it"; exit 1; }
cp $README $W/$N/README.txt
cp $NOTICE $W/$N/KANOK-NOTICE.txt
echo "packages: main $(ls $MAIN/*.deb | wc -l) + Thai language pack $(ls $LANG_TH/*.deb | wc -l) - librelogo 1 = $(ls $W/$N/DEBS | wc -l)"
(cd $W/$N/DEBS && sha256sum *.deb) > $OUT/$N.debs.sha256
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime='2026-10-27 00:00:00Z' -C $W -cf - $N | gzip -n -9 > $OUT/$N.tar.gz
(cd $OUT && sha256sum $N.tar.gz > $N.tar.gz.sha256 && cat $N.tar.gz.sha256 && stat -c '%s bytes' $N.tar.gz)
tar -tzvf $OUT/$N.tar.gz > $OUT/$N.contents.txt
