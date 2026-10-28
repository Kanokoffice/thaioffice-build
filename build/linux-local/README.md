# Local Linux build (the .deb packages of release v26.8.1.1-kanok1)

`KanokOffice_26.8.1.1_Linux_x86-64_deb_th.tar.gz` of release `v26.8.1.1-kanok1` was built with these scripts
from the tree of tag `v26.8.1.1-kanok1` (`088f40d`) in an `ubuntu:24.04` container (GCC 13; LibreOffice 26.8
needs GCC 13+ or Clang 18+). The office uses the system's Python (3.12), so the packages run on Ubuntu 24.04
and distributions based on it; Debian 12 is too old (glibc 2.36, GCC 12).

Layout in the build container (`WORK`, default `/w`): `src/` = the upstream source and translations tarballs
(checked against `build/upstream.sha256`), `out/ext-tar/` = the files of the release asset
`kanokoffice-26.8.1.1-kanok1-external-sources.tar` (the Linux build uses 104 of them), `src-kanok1/` = build
tree, branding and logs.

| Step | Script | What it does |
|---|---|---|
| 00 | `00-build-env.sh` | Build tools and `apt-get build-dep libreoffice` in the container; the user the build runs as |
| 20 | `20-build.sh <repo.tar>` | `repo.tar` = `git archive -o repo.tar v26.8.1.1-kanok1`. Unpacks, patches (`patches/series`), copies `overlay/` (every file compared afterwards), checks the TH SarabunPSK files, configures with `configure-linux.txt` and runs `make` (8 jobs) |
| 30 | `30-pack-deb.sh <tree> README-package.txt overlay/readlicense_oo/license/KANOK-NOTICE.txt <out>` | The release tarball: `DEBS/` (main product + Thai language pack), `README.txt`, `KANOK-NOTICE.txt`; reproducible, so the same packages give the same SHA-256 |
| 40, 41 | `41-run-test.sh <tar.gz> <system> <out>` | Install test in a clean container without network (`test-base/Dockerfile.<system>`: the system and the libraries the office links to, no KanokOffice): installs as `README.txt` says, then `40-test-deb.sh` runs the checks |

`40-test-deb.sh` checks: `apt install ./DEBS/*.deb`, `soffice --version`, Maintainer of every package, the
TH SarabunPSK files byte for byte, `KANOK-NOTICE.txt` (= the overlay file) and the Linux edition of the notices,
the About box text in English and Thai (`expect/`), the Thai start screen text, a Thai document converted to PDF
(the text read back and a Thai font embedded), `build/check-install.py` (the checks of the Windows install test)
and the two bundled extensions. It also takes screenshots of the About box with the Thai and the English user
interface; they are not counted as checks: look at them.

Results for the release tarball: Ubuntu 24.04 all checks ok; Debian 12 installs but the office does not start
(needs glibc 2.38 and the libstdc++ of GCC 13); Ubuntu 26.04 runs the office but not its Python (the office
links to Python 3.12, the system has 3.14), so `check-install.py` fails there and the bundled Python extension
(Buddhist-era dates) cannot load.

Two things in the packages that come from upstream:
- the packages declare no library dependencies (`README-package.txt` lists what a minimal system needs);
- with the system Python, `scp2/InstallModule_python.mk` does not pass `ENABLE_LIBRELOGO`, so the pyuno package
  declares Conflicts/Replaces with the LibreLogo package that is still built. `apt` refuses the set with both, so
  `30-pack-deb.sh` leaves the LibreLogo package out (it stops if pyuno no longer declares the conflict).

The scripts are the ones that made the release; paths and the build user became parameters (with the values
of that run as defaults) and the configure options moved into `configure-linux.txt` (the same options:
the substituted list is identical to the one of the release run). After that change, `30-pack-deb.sh` made a
tarball byte for byte identical to the release asset and `41-run-test.sh ... ubuntu-24.04` passed all checks;
`00-build-env.sh` and `20-build.sh` were not run again.
