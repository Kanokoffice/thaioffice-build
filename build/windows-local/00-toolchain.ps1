# KanokOffice local Windows build VM: toolchain as on the GitHub windows-2022 runner (workflow windows-msi.yml)
# VS 2022 Community (C++ x64, ATL, C++ 2022 Redistributable MSMs, Windows 11 SDK) + Cygwin + make/pkgconf/ccache
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
New-Item -ItemType Directory -Force -Path C:\lo\dl, C:\lo\logs | Out-Null
$log = 'C:\lo\logs\00-toolchain.log'
function Say($m) { $l = '{0:HH:mm:ss} {1}' -f (Get-Date), $m; Write-Host $l; Add-Content $log $l }

# 1. Visual Studio Community 2022
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$req = 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64','Microsoft.VisualStudio.Component.VC.ATL','Microsoft.VisualStudio.Component.VC.Redist.MSM','Microsoft.Net.Component.4.8.SDK','Microsoft.VisualStudio.Component.VC.Llvm.Clang','Microsoft.VisualStudio.Component.VC.CMake.Project'   # 4.8 SDK: al.exe; clang-cl: Skia; CMake (as on the runner)
$have = if (Test-Path $vswhere) { & $vswhere -version '[17.0,18.0)' -products Microsoft.VisualStudio.Product.Community -requires $req -latest -property installationPath } else { $null }
if (-not $have) {
  $bs = 'C:\lo\dl\vs_community.exe'
  curl.exe -fL --retry 5 --retry-delay 10 https://aka.ms/vs/17/release/vs_community.exe -o $bs
  if ($LASTEXITCODE -ne 0) { throw 'VS bootstrapper download failed' }
  $sig = Get-AuthenticodeSignature $bs
  Say "vs_community.exe signature: $($sig.Status) / $($sig.SignerCertificate.Subject)"
  if ($sig.Status -ne 'Valid') { throw 'VS bootstrapper signature not valid' }
  $a = @('--quiet','--wait','--norestart','--nocache')
  foreach ($c in $req + 'Microsoft.VisualStudio.Component.Windows11SDK.26100') { $a += '--add'; $a += $c }
  Say "VS install: $($a -join ' ')"
  $p = Start-Process $bs -ArgumentList $a -Wait -PassThru
  Say "VS installer exit=$($p.ExitCode)"   # 3010 = done, reboot required
  if ($p.ExitCode -notin 0, 3010) { throw "VS install failed: $($p.ExitCode)" }
  $have = & $vswhere -version '[17.0,18.0)' -products Microsoft.VisualStudio.Product.Community -requires $req -latest -property installationPath
  if (-not $have) { throw 'VS Community with the required components not found after install' }
}
Say "Visual Studio Community: $have"
Say ("VC tools: " + ((Get-ChildItem "$have\VC\Tools\MSVC" -Directory).Name -join ', '))

# 2. Windows SDK incl. MSI tools (configure needs msidb/msiinfo/msitran/msimsp/uuidgen)
$kits = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots').KitsRoot10
Say ("Windows SDK bin: " + ((Get-ChildItem (Join-Path $kits 'bin') -Directory | Where-Object Name -match '^10\.').Name -join ', '))
$miss = @(foreach ($t in 'msidb.exe','msiinfo.exe','msitran.exe','msimsp.exe','uuidgen.exe') { if (-not (Get-ChildItem (Join-Path $kits 'bin') -Recurse -Filter $t -ErrorAction SilentlyContinue | Select-Object -First 1)) { $t } })
if ($miss) {
  Say "SDK tools missing: $($miss -join ', ') "
  throw "Windows SDK MSI tools missing: $($miss -join ', ') (install the SDK feature 'MSI Tools' / OptionId.MSIInstallTools)"
}

# 3. Cygwin + packages (same list and mirror as the workflow)
$setup = 'C:\lo\dl\cygwin-setup.exe'
curl.exe -fL --retry 8 --retry-delay 15 --retry-all-errors --connect-timeout 30 https://cygwin.com/setup-x86_64.exe -o $setup
if ($LASTEXITCODE -ne 0) { throw 'Cygwin installer download failed.' }
$sig = Get-AuthenticodeSignature -LiteralPath $setup
Say "Cygwin setup signature: $($sig.Status) / $($sig.SignerCertificate.Subject)"
if ($sig.Status -ne 'Valid') { throw 'The Cygwin installer signature is not valid.' }
$packages = @(
  'autoconf','automake','bison','cabextract','diffutils','file','flex','gawk','gettext-devel',
  'git','gperf','libxml2-devel','libxslt','make','nasm','patch','perl','perl-Archive-Zip',
  'perl-Font-TTF','perl-IO-String','pkg-config','python3','rsync','tar','unzip','wget','which',
  'xz','zip'
) -join ','
$p = Start-Process -FilePath $setup -WindowStyle Hidden -Wait -PassThru -ArgumentList @(
  '-q','-n','-N','-d','-R','C:\cygwin64','-s','https://mirrors.kernel.org/sourceware/cygwin/','-P',$packages)
if ($p.ExitCode -ne 0) { throw "Cygwin setup failed with exit code $($p.ExitCode)." }
Say 'Cygwin installed'

$toolDir = 'C:\cygwin64\opt\lo\bin'
New-Item -ItemType Directory -Force -Path $toolDir | Out-Null
$downloads = @{
  'make.exe'          = 'https://dev-www.libreoffice.org/bin/cygwin/make-4.2.1-msvc.exe'
  'pkgconf-2.4.3.exe' = 'https://dev-www.libreoffice.org/extern/pkgconf-2.4.3.exe'
}
foreach ($e in $downloads.GetEnumerator()) {
  $dst = Join-Path $toolDir $e.Key
  curl.exe -fL --retry 5 --retry-delay 5 $e.Value -o $dst
  if ($LASTEXITCODE -ne 0 -or (Get-Item -LiteralPath $dst).Length -lt 10000) { throw "Downloading $($e.Key) failed." }
  Say "$($e.Key) SHA-256 $((Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash)"
}
$zip = 'C:\lo\dl\ccache.zip'
curl.exe -fL --retry 5 https://github.com/ccache/ccache/releases/download/v4.14.2/ccache-4.14.2-windows-x86_64.zip -o $zip
$h = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower()
if ($h -ne '6993ce645e53192cec592ee23186200b574ac4c59097ecde8d9cfd681b47ae84') { throw "ccache zip hash mismatch: $h" }
Expand-Archive -LiteralPath $zip -DestinationPath C:\lo\dl\ccache-x -Force
Copy-Item (Get-ChildItem C:\lo\dl\ccache-x -Recurse -Filter ccache.exe | Select-Object -First 1).FullName "$toolDir\ccache.exe"
Say 'toolchain done'
