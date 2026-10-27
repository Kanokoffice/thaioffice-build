#!/usr/bin/env python3
# Build the RTF shown on the LicenseAgreement page of the MSI from build/terms-of-use-th.md.
#
# usage: make-license-rtf.py <terms.md> <out.rtf> [<out.rtf> ...]
#
# The packager (solenv/bin/modules/installer/windows/idtglobal.pm, add_licensefile_to_database) puts the
# RTF into the Text column of Control.idt on one line: it strips each line's trailing whitespace and joins
# the lines with one space. So every line written here ends with a control word ("\par"), where that
# space is only the delimiter, and no line breaks inside Thai text (a space there would show up).
# Non-ASCII characters are written as \uN? escapes, so the RTF is plain ASCII and does not depend on
# the code page of the MSI database or of its language transforms.
import re
import sys

FONT = r"{\fonttbl{\f0\fswiss\fcharset222 Tahoma;}}"


def esc(s):
    out = []
    for ch in s:
        o = ord(ch)
        if ch in "\\{}":
            out.append("\\" + ch)
        elif o < 128:
            out.append(ch)
        elif o > 0xFFFF:
            raise SystemExit(f"character outside the BMP: U+{o:X}")
        else:
            out.append(f"\\u{o if o < 0x8000 else o - 0x10000}?")
    return "".join(out)


def inline(s):
    # **bold** inside a line
    parts = re.split(r"\*\*(.+?)\*\*", s)
    return "".join(esc(p) if i % 2 == 0 else r"{\b " + esc(p) + "}" for i, p in enumerate(parts))


def main():
    src, outs = sys.argv[1], sys.argv[2:]
    if not outs:
        raise SystemExit("usage: make-license-rtf.py <terms.md> <out.rtf> [<out.rtf> ...]")
    lines = open(src, encoding="utf-8").read().split("\n")
    body = []
    for l in lines:
        if not l.strip():
            continue
        if l.startswith("# "):
            body.append(r"\pard\sa120\qc{\b\fs22 " + esc(l[2:].strip()) + r"}\par")
        elif l.startswith("  - "):
            body.append(r"\pard\li560\fi-200\tx560\sa30 " + esc("–") + r"\tab " + inline(l[4:]) + r"\par")
        elif l.startswith("- "):
            body.append(r"\pard\li280\fi-200\tx280\sa30 " + esc("•") + r"\tab " + inline(l[2:]) + r"\par")
        else:
            body.append(r"\pard\sb140\sa50 " + inline(l) + r"\par")
    head = r"{\rtf1\ansi\ansicpg874\deff0\uc1" + FONT + r"\viewkind4\f0\fs17"
    rtf = [head + body[0]] + body[1:] + ["}"]
    text = "\r\n".join(rtf) + "\r\n"
    assert all(ord(c) < 128 for c in text)
    for o in outs:
        with open(o, "w", encoding="ascii", newline="") as f:
            f.write(text)


if __name__ == "__main__":
    main()
