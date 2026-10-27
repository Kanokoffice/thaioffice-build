#!/bin/bash
# Resume after a failed MSI packaging step: same tree, no configure; make only redoes what is left
# (compiled objects are up to date), with the temp dir on C:\lo (see 20-build.sh).
set -eo pipefail
export PATH="/opt/lo/bin:/usr/local/bin:/usr/bin:/bin:$PATH" HOME=/home/builder CCACHE_DIR='C:\lo\ccache' CCACHE_MAXSIZE=20G
mkdir -p /cygdrive/c/lo/tmp; export TMPDIR=C:/lo/tmp TMP=C:/lo/tmp TEMP=C:/lo/tmp
root=/cygdrive/c/lo; cd "$root/libreoffice-26.8.1.1"
echo "$(date +%H:%M:%S) step: make -j${BUILD_JOBS:-6} build (resume, TMPDIR=C:/lo/tmp)" | tee -a "$root/logs/20-build-steps.log"
s=$(date +%s); rc=0
/opt/lo/bin/make.exe -j${BUILD_JOBS:-6} build TMPDIR=C:/lo/tmp TMP=C:/lo/tmp > "$root/diag/make-resume.log" 2>&1 || rc=$?
echo "$(date +%H:%M:%S) make (resume) rc=$rc elapsed=$(( ($(date +%s) - s) / 60 )) min" | tee -a "$root/logs/20-build-steps.log"
tail -n 30 "$root/diag/make-resume.log"; exit $rc
