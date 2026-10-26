# thaioffice-build

Internal build repository for the Windows installer (MSI) of KanokOffice 26.8.1.1 (based on LibreOffice 26.8.1.1).
⛔ Private. Do not make this repository public, and do not add an organization description or logo.

| Path | Contents |
|---|---|
| `.github/workflows/windows-msi.yml` | Manual workflow: `mode=probe` (runner hardware) or `mode=build` (MSI) |
| `build/upstream.sha256` | SHA-256 of the upstream LibreOffice source and translations tarballs (downloaded by the workflow) |
| `build/configure-windows.txt` | Configure options for Windows |
| `patches/` + `patches/series` | Our changes to LibreOffice files (`patch -p1`, in order) |
| `overlay/` | Files replaced or added whole (icons, MSI codes file). Copy with `cp -a --remove-destination` |
| `branding/` | Images for `--with-branding` |

Actions budget (private repo, Free plan): 2,000 minutes per month, Windows minutes count double.
Artifacts are kept 1 day; download them, then delete them.
