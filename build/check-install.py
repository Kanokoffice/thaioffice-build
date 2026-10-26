# KanokOffice install check (Windows install-test and Linux): connects to a running office on a UNO pipe
# and checks the Thai defaults, default templates, bundled extensions and font from the kanok module.
# Usage: <office python> check-install.py <pipe-name>   · exit 0 = all checks passed, 3 = a check failed
import sys, time
import uno
from com.sun.star.beans import PropertyValue

def pv(n, v):
    p = PropertyValue(); p.Name = n; p.Value = v; return p

pipe = sys.argv[1]
local = uno.getComponentContext()
res = local.ServiceManager.createInstanceWithContext("com.sun.star.bridge.UnoUrlResolver", local)
last = None
for i in range(120):   # a first start with a new profile may restart the office once
    try:
        ctx = res.resolve("uno:pipe,name=%s;urp;StarOffice.ComponentContext" % pipe)
        smgr = ctx.ServiceManager
        cp = smgr.createInstance("com.sun.star.configuration.ConfigurationProvider")
        cp.createInstanceWithArguments("com.sun.star.configuration.ConfigurationAccess", (pv("nodepath", "/org.openoffice.Setup/L10N"),))
        break
    except Exception as e:
        last = e; time.sleep(1)
else:
    print("could not connect:", last); sys.exit(1)

fails = []
def check(name, got, want):
    ok = got == want
    print("%-4s %-34s %r%s" % ("ok" if ok else "FAIL", name, got, "" if ok else "  (want %r)" % (want,)))
    if not ok: fails.append(name)

def cfg(path, name):
    return cp.createInstanceWithArguments("com.sun.star.configuration.ConfigurationAccess", (pv("nodepath", path),)).getByName(name)

check("UILocale (kanok.xcd)", cfg("/org.openoffice.Office.Linguistic/General", "UILocale"), "th")
check("UI language chosen (ooLocale)", cfg("/org.openoffice.Setup/L10N", "ooLocale"), "th")
check("document language (DefaultLocale)", cfg("/org.openoffice.Office.Linguistic/General", "DefaultLocale"), "th-TH")
uicd = ctx.getValueByName("/singletons/com.sun.star.frame.theUICommandDescription")
label = dict((p.Name, p.Value) for p in uicd.getByName("com.sun.star.text.TextDocument").getByName(".uno:Save"))["Label"]
check("menu label .uno:Save", label, "~บันทึก")
desk = smgr.createInstance("com.sun.star.frame.Desktop")
for url, fam, sty in (("private:factory/swriter", "ParagraphStyles", "Standard"), ("private:factory/scalc", "CellStyles", "Default")):
    d = desk.loadComponentFromURL(url, "_blank", 0, (pv("Hidden", True),))
    st = d.getStyleFamilies().getByName(fam).getByName(sty)
    check(url[16:] + " default font", (st.CharFontName, st.CharHeight), ("TH SarabunPSK", 16.0))
    d.close(True)
pip = ctx.getValueByName("/singletons/com.sun.star.deployment.PackageInformationProvider")
ids = sorted(x[0] for x in pip.getExtensionList())
for ext in ("org.kanok.bedate", "org.thaioffice.dict.th"):
    check("extension " + ext, ext in ids, True)
try:
    check("service org.kanok.BEDateJob", smgr.createInstanceWithContext("org.kanok.BEDateJob", ctx) is not None, True)
except Exception as e:
    check("service org.kanok.BEDateJob", str(e), True)
loc = uno.createUnoStruct("com.sun.star.lang.Locale"); loc.Language = "th"; loc.Country = "TH"
lsm = smgr.createInstance("com.sun.star.linguistic2.LinguServiceManager")
check("th-TH spell checker available", len(lsm.getAvailableServices("com.sun.star.linguistic2.SpellChecker", loc)) > 0, True)
# TH SarabunPSK (module kanok, share/fonts/truetype) is a font the office can use: the 4 styles by weight and slant
dev = smgr.createInstanceWithContext("com.sun.star.awt.Toolkit", ctx).createScreenCompatibleDevice(16, 16)
styles = sorted(set((f.Weight > 100, f.Slant.value != "NONE") for f in dev.getFontDescriptors() if f.Name == "TH SarabunPSK"))
check("font TH SarabunPSK (4 styles)", len(styles), 4)
# Python macros through the script framework (the bundled Windows Python ships without pip/setuptools)
# (not Hidden: HelloWorldPython writes into the desktop's current component, which a hidden document never is)
d = desk.loadComponentFromURL("private:factory/swriter", "_blank", 0, ())
try:
    d.getScriptProvider().getScript("vnd.sun.star.script:HelloWorld.py$HelloWorldPython?language=Python&location=share").invoke((), (), ())
    check("Python macro HelloWorldPython", "Hello World (in Python)" in d.Text.String, True)
except Exception as e:
    check("Python macro HelloWorldPython", str(e), True)
d.close(True)
try:
    desk.terminate()
except Exception:
    pass
print("checks failed: %d" % len(fails))
sys.exit(3 if fails else 0)
