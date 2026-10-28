#!/bin/bash
# KanokOffice .deb install test in a clean container (--network none, see 41-run-test.sh): install as the package
# README says, then the checks of the Windows install test (windows-local/40-install-test.ps1) + About box text,
# KANOK-NOTICE.txt, Maintainer of every package. usage (in the container): 40-test-deb.sh <tar.gz> <out dir>
# /t holds build/check-install.py and build/windows-local/gui-client.py, /t/expect the expected texts.
# exit 0 = all checks ok, 3 = a check failed. The two About box screenshots are not checks: look at them.
set -u
TGZ=$1; O=$2; mkdir -p $O
fails=0; ok(){ echo "ok   $*" | tee -a $O/summary.txt; }; bad(){ echo "FAIL $*" | tee -a $O/summary.txt; fails=$((fails+1)); }
: > $O/summary.txt
. /etc/os-release; echo "system: $PRETTY_NAME · glibc $(ldd --version | head -1 | awk '{print $NF}') · network: $(ls /sys/class/net | tr '\n' ' ')" | tee -a $O/summary.txt
# 1 unpack + install exactly as README-th-en.txt says
mkdir -p /tmp/x && tar -xzf $TGZ -C /tmp/x
(cd /tmp/x && find . | sort) > $O/package-tree.txt
D=$(find /tmp/x -mindepth 1 -maxdepth 1 -type d | head -1)
cd $D && apt-get install -y ./DEBS/*.deb > $O/apt-install.log 2>&1; rc=$?
[ $rc = 0 ] && ok "apt install ./DEBS/*.deb rc=0 · $(ls DEBS/*.deb | wc -l) packages" || bad "apt install rc=$rc"
cd /
P=/opt/kanokoffice26.8/program; B=/opt/kanokoffice26.8
# 2 version
timeout 120 $P/soffice --version > $O/version.txt 2>&1; rc=$?
[ $rc = 0 ] && grep -q KanokOffice $O/version.txt && ok "soffice --version: $(head -1 $O/version.txt)" || { bad "soffice --version rc=$rc: $(head -3 $O/version.txt | tr '\n' ' ')"; }
# 3 Maintainer of every package in the tarball
n=0; m=0; for f in $D/DEBS/*.deb; do n=$((n+1)); x=$(dpkg-deb -f $f Maintainer); echo "$(basename $f) | $x" >> $O/maintainer.txt; [ "$x" = "NALLTC Limited" ] || [[ "$x" == "NALLTC Limited <"* ]] && m=$((m+1)); done
[ $m = $n ] && ok "Maintainer NALLTC Limited $m/$n" || bad "Maintainer NALLTC Limited $m/$n"
# 4 TH SarabunPSK files byte for byte
printf '%s\n' \
  '2936ea292bf2b82c572ed50837dc4a04170076b561bbfc5a9306037a989b470a  THSarabun.ttf' \
  '969fe7493a68f136dab33f51fabcbcaa44fe040582bec1a575e707f1850eb06c  THSarabun-Bold.ttf' \
  '9fd6e9672f5a78edf186591b8a9f376b8c27d0aac37875f818670a075995cec9  THSarabun-Italic.ttf' \
  'd52e0c8a058afc18f45c50b90f48de5954a46c0868ac826932ba5248b128ffc0  THSarabun-BoldItalic.ttf' \
  'f7a2fc4da4010c59c03df9dc17a8e44ff4860916a9a82f1bde8c929887821a31  DIP-SIPA-Font-License-Agreement.txt' \
  | (cd $B/share/fonts/truetype 2>/dev/null && sha256sum -c -) > $O/fonts-sarabun.txt 2>&1
k=$(grep -c ': OK$' $O/fonts-sarabun.txt); [ "$k" = 5 ] && ok "TH SarabunPSK files sha256 $k/5" || bad "TH SarabunPSK files sha256 $k/5"
# 5 KANOK-NOTICE.txt byte for byte as in the tag's overlay; Linux edition of the notices
if cmp -s $B/KANOK-NOTICE.txt /t/expect/KANOK-NOTICE.txt; then ok "KANOK-NOTICE.txt installed at $B/KANOK-NOTICE.txt (= overlay file)"; else bad "KANOK-NOTICE.txt missing or different"; fi
ls $B > $O/office-root.txt
[ -f $B/THIRD-PARTY-NOTICES ] && [ ! -e $B/THIRD-PARTY-NOTICES-windows ] && ok "THIRD-PARTY-NOTICES (Linux edition) installed, Windows edition not" || bad "THIRD-PARTY-NOTICES edition: $(ls $B | grep -i notice | tr '\n' ' ')"
# 6 About box origin text: English text in the installed dialog file, Thai text in the Thai catalogue
python3 -I - $B /t/expect > $O/about-files.txt 2>&1 <<'EOF'
import sys, gettext, glob
B, E = sys.argv[1], sys.argv[2]
en = open(E + "/about-en.txt", encoding="utf-8").read().rstrip("\n"); th = open(E + "/about-th.txt", encoding="utf-8").read().rstrip("\n")
ui = open(glob.glob(B + "/share/config/soffice.cfg/cui/ui/aboutdialog.ui")[0], encoding="utf-8").read()
import html
print("en in aboutdialog.ui:", html.escape(en, quote=True).replace("&#x27;", "'") in ui or en.replace('"', "&quot;") in ui)
t = gettext.GNUTranslations(open(B + "/program/resource/th/LC_MESSAGES/cui.mo", "rb"))
print("th in cui.mo:", t.pgettext("aboutdialog|description", en) == th)
EOF
grep -q 'en in aboutdialog.ui: True' $O/about-files.txt && ok "About box origin text (English) in aboutdialog.ui" || bad "About box origin text (English): $(cat $O/about-files.txt | tr '\n' ' ')"
grep -q 'th in cui.mo: True' $O/about-files.txt && ok "About box origin text (Thai) in th/cui.mo" || bad "About box origin text (Thai): $(cat $O/about-files.txt | tr '\n' ' ')"
# 7 Thai welcome line (sfx.mo)
grep -q 'ยินดีต้อนรับสู่ กนก ออฟฟิศ!' $P/resource/th/LC_MESSAGES/sfx.mo && ok "Thai welcome string in sfx.mo" || bad "Thai welcome string in sfx.mo"
killoffice(){ pkill -9 -x soffice.bin; pkill -9 -x oosplash; sleep 2; rm -f /tmp/OSL_PIPE_*; }
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
# 8 Thai text to PDF
printf 'กนก ออฟฟิศ ทดสอบภาษาไทย 27/10/2569\n' > /tmp/thai.txt
timeout 180 $P/soffice --headless --norestore -env:UserInstallation=file:///tmp/pconv --convert-to pdf --outdir $O /tmp/thai.txt > $O/convert.txt 2>&1
if [ -s $O/thai.pdf ]; then
  pdftotext $O/thai.pdf - > $O/thai-pdf.txt 2>/dev/null; pdffonts $O/thai.pdf > $O/thai-pdffonts.txt 2>&1
  pdftoppm -r 100 -png -f 1 -l 1 $O/thai.pdf $O/thai-pdf-page 2>/dev/null
  fonts=$(awk 'NR>2{print $1}' $O/thai-pdffonts.txt | tr '\n' ' ')
  grep -q 'กนก ออฟฟิศ ทดสอบภาษาไทย' $O/thai-pdf.txt && ok "Thai PDF $(stat -c %s $O/thai.pdf) bytes · text back from the PDF matches" || bad "Thai PDF text: $(head -2 $O/thai-pdf.txt)"
  # the text layer alone does not show the glyphs are there (dry run: Thai text extractable, page blank): a font with Thai glyphs must be embedded
  echo "$fonts" | grep -q -i -E 'sarabun|thai|tlwg|garuda|loma|kinnari|norasi|waree|umpush|sawasdee|laksaman|purisa' && ok "Thai PDF embeds a Thai font: $fonts" || bad "Thai PDF has no Thai font embedded: $fonts"
else bad "no PDF: $(tail -2 $O/convert.txt | tr '\n' ' ')"; fi
killoffice
# 9 check-install.py (same script as the Windows install test), office's pyuno with the system Python
$P/soffice --headless --norestore -env:UserInstallation=file:///tmp/pchk "--accept=pipe,name=kanokcheck;urp;" > /tmp/so-chk.log 2>&1 &
URE_BOOTSTRAP=vnd.sun.star.pathname:$P/fundamentalrc PYTHONPATH=$P timeout 300 python3 -u /t/check-install.py kanokcheck > $O/check-install.txt 2>&1; rc=$?
[ $rc = 0 ] && ok "check-install.py: $(grep -c '^ok' $O/check-install.txt) ok · $(tail -1 $O/check-install.txt)" || bad "check-install.py rc=$rc: $(grep -E '^FAIL|failed|Error' $O/check-install.txt | head -5 | tr '\n' ' ')"
sleep 3; killoffice
timeout 120 $P/unopkg list --bundled -env:UserInstallation=file:///tmp/pchk > $O/unopkg-bundled.txt 2>&1
k=$(grep -c '^Identifier:' $O/unopkg-bundled.txt); [ "$k" = 2 ] && ok "bundled extensions $k/2: $(grep '^Identifier:' $O/unopkg-bundled.txt | awk '{print $2}' | tr '\n' ' ')" || bad "bundled extensions $k (want 2)"
killoffice
# 10 About box on screen (Xvfb): Thai UI (default) and English UI profile; screenshots
for ui in th en; do
  prof=/tmp/pgui-$ui; rm -rf $prof
  if [ $ui = en ]; then mkdir -p $prof/user; printf '%s' '<?xml version="1.0" encoding="UTF-8"?><oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><item oor:path="/org.openoffice.Office.Linguistic/General"><prop oor:name="UILocale" oor:op="fuse"><value>en-US</value></prop></item></oor:items>' > $prof/user/registrymodifications.xcu; fi
  Xvfb :9 -screen 0 1280x900x24 > /dev/null 2>&1 & xv=$!; sleep 2
  DISPLAY=:9 SAL_USE_VCLPLUGIN=gen $P/soffice --norestore -env:UserInstallation=file://$prof "--accept=pipe,name=kgui$ui;urp;" > /tmp/so-gui-$ui.log 2>&1 &
  sleep 25
  URE_BOOTSTRAP=vnd.sun.star.pathname:$P/fundamentalrc PYTHONPATH=$P timeout 120 python3 /t/gui-client.py kgui$ui about > /tmp/about-$ui.log 2>&1 &
  sleep 12
  # a screenshot is evidence only once looked at: it is taken even when no About box opened (not counted as a check)
  DISPLAY=:9 import -window root $O/about-$ui.png 2>> $O/screenshot.log && echo "info screenshot ($ui UI, look at it): about-$ui.png" | tee -a $O/summary.txt
  killoffice; kill $xv 2>/dev/null; sleep 1
done
echo "checks failed: $fails" | tee -a $O/summary.txt
exit $([ $fails = 0 ] && echo 0 || echo 3)
