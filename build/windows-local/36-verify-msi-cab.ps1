# Byte check of the merge-module files straight from the MSI's embedded cabinets (the admin install leaves out
# files of components whose condition is false, e.g. the arm64 files of the x64 module on an x64 machine)
$ErrorActionPreference = 'Stop'
$msi = (Get-ChildItem C:\lo\out -Filter *.msi | Sort-Object Length -Descending | Select-Object -First 1).FullName
$w = 'C:\lo\vcheck\msi'; Remove-Item $w -Recurse -Force -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force "$w\x" | Out-Null
$wi = New-Object -ComObject WindowsInstaller.Installer
function Call($o, $m, $kind, $a) { $o.GetType().InvokeMember($m, $kind, $null, $o, $a) }
$db = Call $wi 'OpenDatabase' 'InvokeMethod' @([string]$msi, [int]0)
$v = Call $db 'OpenView' 'InvokeMethod' @([string]'SELECT Cabinet FROM Media'); Call $v 'Execute' 'InvokeMethod' @() | Out-Null
$cabs = @(while ($r = Call $v 'Fetch' 'InvokeMethod' @()) { Call $r 'StringData' 'GetProperty' @([int]1) }) | Where-Object { $_ -like '#*' } | ForEach-Object { $_.Substring(1) }
"embedded cabinets: $($cabs -join ', ')"
$msidb = (Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Recurse -Filter msidb.exe | Select-Object -First 1).FullName
Push-Location $w
foreach ($c in $cabs) { & $msidb -d $msi -f $w -x $c | Out-Null; & "$env:SystemRoot\System32\expand.exe" (Join-Path $w $c) '-F:*' "$w\x" | Out-Null }
Pop-Location
$all = 0; $same = 0
foreach ($m in 'Microsoft_VC143_CRT_x64', 'Microsoft_VC143_CRT_x86') {
  foreach ($f in Get-ChildItem "C:\lo\vcheck\$m\cab" -File) {
    $all++; $t = Join-Path "$w\x" $f.Name
    $ok = (Test-Path $t) -and ((Get-FileHash $t -Algorithm SHA256).Hash -eq (Get-FileHash $f.FullName -Algorithm SHA256).Hash)
    if ($ok) { $same++ } else { "  differs or missing in MSI cabinets: $($f.Name)" }
  }
}
"merge-module files: $all · byte-identical in the MSI's cabinets: $same" | Tee-Object -Append C:\lo\out\msm-check.txt
if ($same -ne $all -or $all -eq 0) { exit 3 }
