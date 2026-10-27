# thaioffice-build

Build repository for the Windows installer (MSI) of KanokOffice 26.8.1.1 (based on LibreOffice 26.8.1.1).

| Path | Contents |
|---|---|
| `.github/workflows/windows-msi.yml` | Manual workflow: `mode=probe` (runner hardware) or `mode=build` (MSI) |
| `build/upstream.sha256` | SHA-256 of the upstream LibreOffice source and translations tarballs (downloaded by the workflow) |
| `build/configure-windows.txt` | Configure options for Windows |
| `build/terms-of-use-th.md` | Terms of Use shown on the installer's license page (Thai, the governing text) |
| `build/make-license-rtf.py` | Builds `overlay/setup_native/source/packinfo/license_{en-US,th}.rtf` from it |
| `build/check-install.py` | Checks run against an installed office (install test) |
| `patches/` + `patches/series` | Our changes to LibreOffice files (`patch -p1`, in order) |
| `overlay/` | Files replaced or added whole (icons, MSI codes file, license page RTF, KANOK-NOTICE.txt). Copy with `cp -a --remove-destination` |
| `branding/` | Images for `--with-branding` |

Workflow artifacts can be downloaded by any signed-in GitHub user while they exist: they are kept 1 day; download them, then delete them.
