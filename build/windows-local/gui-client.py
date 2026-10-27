# UNO client for the network test (run with the office's own python.exe).
# usage: gui-client.py <pipe> write <file url> | about | quit | loadurl <url>
import sys
import time

import uno
from com.sun.star.beans import PropertyValue


def connect(pipe):
    local = uno.getComponentContext()
    resolver = local.ServiceManager.createInstanceWithContext("com.sun.star.bridge.UnoUrlResolver", local)
    for _ in range(120):
        try:
            return resolver.resolve(f"uno:pipe,name={pipe};urp;StarOffice.ComponentContext")
        except Exception:
            time.sleep(1)
    raise SystemExit(f"no office on pipe {pipe}")


def prop(name, value):
    p = PropertyValue()
    p.Name, p.Value = name, value
    return p


def main():
    pipe, cmd = sys.argv[1], sys.argv[2]
    ctx = connect(pipe)
    smgr = ctx.ServiceManager
    desk = smgr.createInstanceWithContext("com.sun.star.frame.Desktop", ctx)
    if cmd == "write":
        url = sys.argv[3]
        d = desk.loadComponentFromURL("private:factory/swriter", "_blank", 0, ())
        d.getCurrentController().getFrame().activate()
        t = d.getText()
        t.insertString(t.getEnd(), "เอกสารทดสอบ: เนื้อหานี้ต้องไม่ออกจากเครื่อง · network test document 2569\n", False)
        d.storeAsURL(url, ())
        d.close(True)
        d = desk.loadComponentFromURL(url, "_blank", 0, ())
        d.getCurrentController().getFrame().activate()
        print("written and reopened", url)
    elif cmd == "about":
        frame = desk.getCurrentFrame() or desk.getFrames().getByIndex(0)
        helper = smgr.createInstanceWithContext("com.sun.star.frame.DispatchHelper", ctx)
        helper.executeDispatch(frame, ".uno:About", "", 0, ())
        print("about dialog closed")
    elif cmd == "loadurl":
        d = desk.loadComponentFromURL(sys.argv[3], "_blank", 0, (prop("Hidden", True),))
        print("loaded", sys.argv[3], bool(d))
        if d:
            d.close(True)
    elif cmd == "quit":
        try:
            desk.terminate()
        except Exception:
            pass  # the bridge goes away with the office
        print("terminated")
    else:
        raise SystemExit(f"unknown command {cmd}")


main()
