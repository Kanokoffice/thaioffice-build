#!/bin/bash
# Bring the existing build tree up to the release changes without configure: patch kanok-v1-eula.diff
# (license page, About notice, KANOK-NOTICE.txt), copy the new overlay files, and regenerate only
# instsetoo_native/util/openoffice.lst from its .in (config.status, same values as the configure run).
set -eo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
root=/cygdrive/c/lo; kit=$root/kit/release; cd "$root/libreoffice-26.8.1.1"
echo "$(date +%H:%M:%S) step: apply release changes" | tee -a "$root/logs/20-build-steps.log"
patch -p1 --dry-run --no-backup-if-mismatch < "$kit/kanok-v1-eula.diff"
patch -p1 --no-backup-if-mismatch < "$kit/kanok-v1-eula.diff"
(cd "$kit/overlay" && find . -type f) | while read -r f; do cp --remove-destination "$kit/overlay/$f" "$f"; cmp "$kit/overlay/$f" "$f"; echo "overlay $f"; done
./config.status --file=instsetoo_native/util/openoffice.lst
# the .mo rule (solenv/gbuild/AllLangMoTarget.mk) does not depend on the .po, so drop the Thai cui catalogue the
# patch changed (About box notice); make then builds it again from translations/source/th/cui/messages.po
rm -f workdir/MoTarget/cuith.mo instdir/program/resource/th/LC_MESSAGES/cui.mo
if grep -q HIDELICENSEDIALOG instsetoo_native/util/openoffice.lst; then echo 'HIDELICENSEDIALOG still set'; exit 3; fi
sha256sum instsetoo_native/util/openoffice.lst setup_native/source/packinfo/license_*.rtf readlicense_oo/license/KANOK-NOTICE.txt
echo "$(date +%H:%M:%S) release changes applied" | tee -a "$root/logs/20-build-steps.log"
