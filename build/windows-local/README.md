# Local Windows build (the MSI of release v26.8.1.1-kanok1)

The MSI of release `v26.8.1.1-kanok1` was built with these scripts on a Windows 11 machine with
**Visual Studio Community 2022**, not on a GitHub runner, so that the Microsoft Visual C++ merge modules in
the MSI come from NALLTC Limited's own Visual Studio installation. The build steps themselves are the ones
of `.github/workflows/windows-msi.yml` (the "Unpack, patch, overlay" and "Configure" steps are copied verbatim).

Layout on the build machine: everything under `C:\lo` (`C:\lo\kit` = this folder, `C:\lo\in` = upstream
tarballs and the external tarballs from the release assets, `C:\lo\libreoffice-26.8.1.1` = build tree).
PowerShell 5.1: the `.ps1` files are UTF-8 with BOM.

| Step | Script | What it does |
|---|---|---|
| 00 | `00-toolchain.ps1`, `01-netfx-sdk.ps1` | VS Community 2022 (C++ x64, ATL, C++ redistributable MSMs, .NET 4.8 SDK, clang-cl, CMake, Windows 11 SDK 26100), Cygwin with the workflow's packages, make, pkgconf, ccache |
| 10 | `10-evidence.ps1` | Records the VS installation (`vswhere.json`), tool versions and the SHA-256 of the two VC++ merge modules |
| 20 | `20-build.sh <commit>` | Checks out this repository at `<commit>`, unpacks, patches, overlays, configures and runs `make` (6 jobs) |
| 21 | `21-package.sh` | Runs `make` again in the same tree (no configure): used to package again after a change that needs no compiling |
| 22 | `22-apply-release.sh` | Brings an existing tree up to a later commit's packaging changes: `patches/kanok-v1-eula.diff` and the new overlay files, copied to `C:\lo\kit\release\` (`kanok-v1-eula.diff` + `overlay/`) |
| 30 | `30-stage.ps1` | The workflow's stage step: copies the MSI to `C:\lo\out`, admin install, payload checks |
| 35, 36 | `35-verify-msm.ps1`, `36-verify-msi-cab.ps1` | The VC++ merge modules in the MSI are byte for byte the ones of this machine's VS Community |
| 40 | `40-install-test.ps1` | The workflow's install test (`build/check-install.py` and the other checks) |
| 45, 46 | `45-check-eula.ps1`, `46-eula-ui.ps1` | License page: MSI tables, and the wizard driven for real (Next only works once the box is ticked), English and Thai |
| 50–52 | `50-nettest-start.ps1`, `51-gui-session.ps1`, `52-nettest-collect.ps1` | Network test: every connection and DNS query of the installed office is logged while it is installed, tested and used; two positive controls at the end |

`run-task.ps1` runs a long step as a scheduled task (it survives the remote session ending); `run-itask.ps1`
runs a step in the logged-on user's desktop session (wizard and GUI tests). `gui-client.py` and
`net-control.py` are run with the office's own `python.exe` by the network test.

How the release MSI was made: `20-build.sh b7f53e1` (packaging then stopped on a temp-dir permission problem,
fixed in `20-build.sh` since) → `21-package.sh` → `22-apply-release.sh` with the changes of commit `e4d1402` →
`21-package.sh` → `30`, `35`, `36`, `45`, `46`, `40`, `50`–`52`. Between `b7f53e1` and `e4d1402` the other
commits change only the install-test script, so the MSI corresponds to the tree of `e4d1402`.

Two things to know when packaging again in an existing tree (a fresh build does not need them):
the Thai strings of an installer `.ulf` file must stay together with that file's other entries in the
`.po` file (the merge tool reads the entries in order), and the `.mo` catalogues do not depend on their
`.po` files in make, so a changed catalogue has to be deleted first (`22-apply-release.sh` does this).
