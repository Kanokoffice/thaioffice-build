# Stage and check MSI — copied verbatim from .github/workflows/windows-msi.yml (generated)
$env:LO_ROOT='C:\lo'; $env:LO_VERSION='26.8.1.1'; $env:GITHUB_OUTPUT='C:\lo\logs\stage-output.txt'
$src = Join-Path $env:LO_ROOT "libreoffice-$env:LO_VERSION"
$msi = @(Get-ChildItem -Path (Join-Path $src 'workdir\installation') -Recurse -Filter *.msi -ErrorAction SilentlyContinue)
if ($msi.Count -eq 0) { "msi_found=false" >> $env:GITHUB_OUTPUT; Write-Host 'No MSI produced.'; exit 0 }
$out = Join-Path $env:LO_ROOT 'out'
# Only the largest MSI is the installer; the small per-language ones are intermediates
# (round 1 had two different kanokoffice268_en-US.msi, so copying all of them overwrote one)
$instRoot = Join-Path $src 'workdir\installation'
foreach ($m in $msi) { "found: {0}  {1} bytes" -f $m.FullName.Substring($instRoot.Length), $m.Length }
$main = $msi | Sort-Object Length -Descending | Select-Object -First 1
Copy-Item $main.FullName $out
$h = (Get-FileHash $main.FullName -Algorithm SHA256).Hash.ToLower()
"{0}  {1}" -f $h, $main.Name | Set-Content (Join-Path $out 'SHA256SUMS.txt')
"staged: $($main.Name)  $($main.Length) bytes  sha256 $h"
# Administrative install = unpack files without installing; check the payload
$adm = Join-Path $env:LO_ROOT 'admin'
$p = Start-Process msiexec.exe -Wait -PassThru -ArgumentList @('/a', "`"$($main.FullName)`"", '/qn', "TARGETDIR=`"$adm`"")
"admin-install exit=$($p.ExitCode)"
$files = @(Get-ChildItem $adm -Recurse -File)
"payload files: $($files.Count)"
foreach ($n in 'soffice.exe','soffice.com','THIRD-PARTY-NOTICES','NOTICE') {
  $f = $files | Where-Object Name -eq $n | Select-Object -First 1
  "{0}: {1}" -f $n, ($(if ($f) { $f.FullName.Substring($adm.Length) } else { 'MISSING' }))
}
$tpn = $files | Where-Object Name -eq 'THIRD-PARTY-NOTICES' | Select-Object -First 1
if ($tpn) { "THIRD-PARTY-NOTICES edition: $((Select-String -Path $tpn.FullName -Pattern 'Windows Installer package|Linux \.deb packages' | Select-Object -First 1).Line)" }
"LiberationSansNarrow files: $(@($files | Where-Object Name -like 'LiberationSansNarrow*').Count)"
"Thai UI resource files (*th*.mo under resource\th): $(@($files | Where-Object { $_.FullName -match '\\resource\\th\\' }).Count)"
"msi_found=true" >> $env:GITHUB_OUTPUT
