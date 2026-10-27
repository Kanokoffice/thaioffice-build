# Install test — the two install-test steps of .github/workflows/windows-msi.yml (generated); run in C:\lo\itest with msi\ holding the MSI
# ITEST_DIR (default C:\lo\itest) holds msi\ ; check-install.py from ITEST_WS (default C:\lo\repo)
$env:GITHUB_WORKSPACE = $(if ($env:ITEST_WS) { $env:ITEST_WS } else { 'C:\lo\repo' })
Set-Location $(if ($env:ITEST_DIR) { $env:ITEST_DIR } else { 'C:\lo\itest' })
New-Item -ItemType Directory -Force out | Out-Null
$m = Get-ChildItem msi -Filter *.msi | Sort-Object Length -Descending | Select-Object -First 1
"MSI: $($m.Name) $($m.Length) bytes"
$sw = [Diagnostics.Stopwatch]::StartNew()
$p = Start-Process msiexec.exe -Wait -PassThru -ArgumentList @('/i', "`"$($m.FullName)`"", '/qn', '/norestart', '/l*v', "`"$PWD\out\install.log`"")
"install exit=$($p.ExitCode) seconds=$([int]$sw.Elapsed.TotalSeconds)"
$com = Get-ChildItem 'C:\Program Files' -Recurse -Filter soffice.com -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $com) { throw 'soffice.com not found after install' }
"installed at: $($com.DirectoryName)"
& $com.FullName --version | Tee-Object out\version.txt
[IO.File]::WriteAllText("$PWD\out\thai.txt", "กนก ออฟฟิศ ทดสอบภาษาไทย 23/10/2569`r`n", [Text.UTF8Encoding]::new($true))
& $com.FullName --headless --convert-to pdf --outdir out out\thai.txt | Tee-Object out\convert.txt
if (Test-Path out\thai.pdf) { "pdf bytes: $((Get-Item out\thai.pdf).Length)" } else { throw 'conversion produced no PDF' }
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
  Where-Object DisplayName -like '*Kanok*' | Select-Object DisplayName, DisplayVersion, Publisher | Format-List | Tee-Object out\uninstall-entry.txt

$dir = (Get-ChildItem 'C:\Program Files' -Recurse -Filter soffice.com -ErrorAction SilentlyContinue | Select-Object -First 1).DirectoryName
# Thai UI language pack installed on this English Windows (default UI_LANGS=en_US,th in Property.idt)
$th = Select-String -Path out\install.log -Pattern 'Feature: gm_Langpack_r_th;' | Select-Object -First 1
"Thai UI langpack feature: $($th.Line)" | Tee-Object out\langpack-th.txt
$thLocal = [bool]($th -and $th.Line -match 'Action: Local')
# Thai welcome line in the Start Center (STR_WELCOME_LINE1)
$mo = [IO.File]::ReadAllBytes("$dir\resource\th\LC_MESSAGES\sfx.mo")
$want = [Text.Encoding]::UTF8.GetBytes('ยินดีต้อนรับสู่ กนก ออฟฟิศ!')
$hex = [BitConverter]::ToString($mo); $found = $hex.Contains([BitConverter]::ToString($want))
"Thai welcome string in sfx.mo: $found" | Tee-Object out\welcome.txt
# bundled Python without pip/setuptools (kanok-v1-nopip.diff); no python-core at all counts as a failure, not a pass
$core = @(Get-ChildItem $dir -Directory -Filter 'python-core-*')
$left = @(foreach ($c in $core) { foreach ($m in 'pip','setuptools','ensurepip','pkg_resources','_distutils_hack') { if (Test-Path (Join-Path $c.FullName "lib\$m")) { "$($c.Name)\lib\$m" } } })
$noPip = ($core.Count -eq 1) -and ($left.Count -eq 0)
"python-core dirs: $($core.Count) (want 1) · pip/setuptools dirs left: $($left -join ', ')" | Tee-Object out\no-pip.txt
# TH SarabunPSK installed byte for byte next to its license (module kanok, legal review §15.20 F-3)
$sarabun = @{ 'THSarabun.ttf' = '2936ea292bf2b82c572ed50837dc4a04170076b561bbfc5a9306037a989b470a'; 'THSarabun-Bold.ttf' = '969fe7493a68f136dab33f51fabcbcaa44fe040582bec1a575e707f1850eb06c';
           'THSarabun-Italic.ttf' = '9fd6e9672f5a78edf186591b8a9f376b8c27d0aac37875f818670a075995cec9'; 'THSarabun-BoldItalic.ttf' = 'd52e0c8a058afc18f45c50b90f48de5954a46c0868ac826932ba5248b128ffc0';
           'DIP-SIPA-Font-License-Agreement.txt' = 'f7a2fc4da4010c59c03df9dc17a8e44ff4860916a9a82f1bde8c929887821a31' }
$fontsOk = $true
foreach ($k in $sarabun.Keys) {
  $f = Join-Path $dir "..\share\fonts\truetype\$k"
  $h = if (Test-Path $f) { (Get-FileHash $f -Algorithm SHA256).Hash.ToLower() } else { 'missing' }
  if ($h -ne $sarabun[$k]) { $fontsOk = $false }
  "$k $h $(if ($h -eq $sarabun[$k]) {'ok'} else {'FAIL'})" | Tee-Object -Append out\fonts-sarabun.txt
}
# office on a UNO pipe, then the same check script as on Linux (office's own Python)
$so = Start-Process "$dir\soffice.exe" -PassThru -ArgumentList @('--headless', '--norestore', '"--accept=pipe,name=kanokcheck;urp;"')
& "$dir\python.exe" "$env:GITHUB_WORKSPACE\build\check-install.py" kanokcheck 2>&1 | Tee-Object out\check-install.txt
$rc = $LASTEXITCODE
Start-Sleep 5
Get-Process soffice* -ErrorAction SilentlyContinue | Stop-Process -Force
& "$dir\unopkg.com" list --bundled 2>&1 | Tee-Object out\unopkg-bundled.txt
$n = @(Select-String -Path out\unopkg-bundled.txt -Pattern '^Identifier:').Count
"bundled extensions: $n (want 2)" | Tee-Object -Append out\unopkg-bundled.txt
if ($rc -ne 0 -or $n -ne 2 -or -not $found -or -not $thLocal -or -not $noPip -or -not $fontsOk) { throw "kanok checks failed: check-install rc=$rc, bundled=$n, welcome=$found, th-langpack=$thLocal, no-pip=$noPip, sarabun-files=$fontsOk" }
