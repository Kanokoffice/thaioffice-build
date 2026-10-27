# Check that the MSI carries the VC++ merge modules of THIS machine's VS Community (MSM_PATH), byte for byte:
#  (1) sha256 of the .msm at MSM_PATH = evidence SHA256.txt
#  (2) every file in each .msm cabinet has a byte-identical copy in the MSI payload (admin install from 30-stage)
#  (3) the MSI ModuleSignature table lists the same module IDs/versions as the .msm files
$ErrorActionPreference = 'Stop'
$src = 'C:\lo\libreoffice-26.8.1.1'; $ev = 'C:\lo\evidence'; $adm = 'C:\lo\admin'; $out = 'C:\lo\out\msm-check.txt'
$lines = @()
$msmPath = ((Select-String -Path "$src\config_host.mk" -Pattern '^export MSM_PATH=(.*)$').Matches[0].Groups[1].Value).Trim()
$msmDir = (Resolve-Path ($msmPath -replace '/', '\')).Path
$lines += "MSM_PATH: $msmPath -> $msmDir"
$want = @{}; Get-Content "$ev\SHA256.txt" | ForEach-Object { $h, $n = $_ -split '\s+', 2; $want[$n.Trim()] = $h }
$ok1 = $true
foreach ($n in 'Microsoft_VC143_CRT_x64.msm', 'Microsoft_VC143_CRT_x86.msm') {
  $h = (Get-FileHash (Join-Path $msmDir $n) -Algorithm SHA256).Hash.ToLower()
  $m = $h -eq $want[$n]; if (-not $m) { $ok1 = $false }
  $lines += "(1) $n sha256 $h evidence $($want[$n]) $(if ($m) {'MATCH'} else {'DIFFERENT'})"
}
$wi = New-Object -ComObject WindowsInstaller.Installer
function Call($o, $m, $kind, $a) { $o.GetType().InvokeMember($m, $kind, $null, $o, $a) }
function Rows($db, $sql, $n) { $v = Call $db 'OpenView' 'InvokeMethod' @([string]$sql); Call $v 'Execute' 'InvokeMethod' @() | Out-Null
  while ($r = Call $v 'Fetch' 'InvokeMethod' @()) { (1..$n | ForEach-Object { Call $r 'StringData' 'GetProperty' @([int]$_) }) -join ' ' } }
# payload hashes
$pay = @{}; Get-ChildItem $adm -Recurse -File | ForEach-Object { $pay[(Get-FileHash $_.FullName -Algorithm SHA256).Hash] = $_.FullName.Substring($adm.Length) }
$lines += "payload files hashed: $($pay.Count)"
$msidb = (Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Recurse -Filter msidb.exe | Select-Object -First 1).FullName
$ok2 = $true; $sigs = @()
foreach ($n in 'Microsoft_VC143_CRT_x64.msm', 'Microsoft_VC143_CRT_x86.msm') {
  $w = "C:\lo\vcheck\$($n -replace '\.msm$','')"; Remove-Item $w -Recurse -Force -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force "$w\cab" | Out-Null
  Copy-Item (Join-Path $msmDir $n) "$w\m.msm"
  Push-Location $w; & $msidb -d "$w\m.msm" -f $w -x MergeModule.CABinet | Out-Null; Pop-Location   # -x writes to the current dir
  & "$env:SystemRoot\System32\expand.exe" "$w\MergeModule.CABinet" '-F:*' "$w\cab" | Out-Null
  $cab = @(Get-ChildItem "$w\cab" -File); $hit = 0
  foreach ($f in $cab) { $h = (Get-FileHash $f.FullName -Algorithm SHA256).Hash; if ($pay.ContainsKey($h)) { $hit++ } else { $lines += "    not in MSI payload: $($f.Name)" } }
  if ($cab.Count -eq 0 -or $hit -ne $cab.Count) { $ok2 = $false }
  $lines += "(2) $n cabinet files: $($cab.Count) · byte-identical in MSI payload: $hit"
  $mdb = Call $wi 'OpenDatabase' 'InvokeMethod' @([string]"$w\m.msm", [int]0)
  $sigs += Rows $mdb 'SELECT ModuleID, Version FROM ModuleSignature' 2
}
$msi = Get-ChildItem C:\lo\out -Filter *.msi | Sort-Object Length -Descending | Select-Object -First 1
$db = Call $wi 'OpenDatabase' 'InvokeMethod' @([string]$msi.FullName, [int]0)
$inMsi = @(Rows $db 'SELECT ModuleID, Version FROM ModuleSignature' 2)
$ok3 = $true; foreach ($s in $sigs) { $m = $inMsi -contains $s; if (-not $m) { $ok3 = $false }; $lines += "(3) .msm ModuleSignature $s in MSI: $m" }
$lines += "MSI ModuleSignature rows: $($inMsi -join ' | ')"
$lines += "RESULT msm-sha=$ok1 payload=$ok2 signature=$ok3"
$lines | Tee-Object $out
if (-not ($ok1 -and $ok2 -and $ok3)) { exit 3 }
