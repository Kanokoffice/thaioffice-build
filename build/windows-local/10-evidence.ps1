# Evidence for the VC++ merge modules used by the local build (step C of the NALLTC VC++ note):
# the .msm files come from Visual Studio Community 2022 installed on this NALLTC machine.
$ErrorActionPreference = 'Stop'
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -version '[17.0,18.0)' -products Microsoft.VisualStudio.Product.Community -requires Microsoft.VisualStudio.Component.VC.Redist.MSM -latest -property installationPath
if (-not $vs) { throw 'Visual Studio Community 2022 with C++ 2022 Redistributable MSMs not found' }
$mm  = Join-Path $vs 'VC\Redist\MSVC\v143\MergeModules'
$out = 'C:\lo\evidence'
New-Item -ItemType Directory -Force -Path $out | Out-Null
foreach ($f in 'Microsoft_VC143_CRT_x64.msm', 'Microsoft_VC143_CRT_x86.msm') { Copy-Item (Join-Path $mm $f) -Destination $out }
& $vswhere -products * -format json | Out-File -Encoding utf8 (Join-Path $out 'vswhere.json')
$rv = Join-Path $vs 'VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt'
$tv = Join-Path $vs 'VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt'
@($(if (Test-Path $rv) { 'VCRedistVersion: ' + (Get-Content $rv -Raw).Trim() } else { 'VCRedistVersion: (file not found)' }),
  $(if (Test-Path $tv) { 'VCToolsVersion: ' + (Get-Content $tv -Raw).Trim() } else { 'VCToolsVersion: (file not found)' }),
  ('MergeModules dir: ' + $mm),
  ('Redist folders: ' + ((Get-ChildItem (Join-Path $vs 'VC\Redist\MSVC') -Directory).Name -join ', '))) | Out-File -Encoding ascii (Join-Path $out 'versions.txt')
# runtime version inside the x64 .msm (File table) — must be >= the compiler toolset version
$wi = New-Object -ComObject WindowsInstaller.Installer
function Call($o, $m, $kind, $a) { $o.GetType().InvokeMember($m, $kind, $null, $o, $a) }
$db = Call $wi 'OpenDatabase' 'InvokeMethod' @([string](Join-Path $out 'Microsoft_VC143_CRT_x64.msm'), [int]0)
$v = Call $db 'OpenView' 'InvokeMethod' @([string]'SELECT FileName, Version FROM File')
Call $v 'Execute' 'InvokeMethod' @() | Out-Null
$rows = while ($r = Call $v 'Fetch' 'InvokeMethod' @()) { '{0} {1}' -f (Call $r 'StringData' 'GetProperty' @([int]1)), (Call $r 'StringData' 'GetProperty' @([int]2)) }
$rows | Out-File -Encoding ascii (Join-Path $out 'msm-x64-files.txt')
Get-ChildItem $out -Filter *.msm | Get-FileHash -Algorithm SHA256 | ForEach-Object { '{0}  {1}' -f $_.Hash.ToLower(), (Split-Path $_.Path -Leaf) } | Out-File -Encoding ascii (Join-Path $out 'SHA256.txt')
Get-Content (Join-Path $out 'versions.txt'), (Join-Path $out 'SHA256.txt')
