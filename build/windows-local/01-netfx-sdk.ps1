# Add components the runner has and configure needs: .NET 4.8 SDK (al.exe), clang-cl (Skia), CMake
$ErrorActionPreference = 'Stop'
$vs = 'C:\Program Files\Microsoft Visual Studio\2022\Community'
$p = Start-Process "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe" -Wait -PassThru -ArgumentList @('modify','--installPath',"`"$vs`"",'--add','Microsoft.Net.Component.4.8.SDK','--add','Microsoft.VisualStudio.Component.VC.Llvm.Clang','--add','Microsoft.VisualStudio.Component.VC.CMake.Project','--quiet','--norestart','--nocache')
"modify exit=$($p.ExitCode)"
Get-ChildItem "${env:ProgramFiles(x86)}\Microsoft SDKs\Windows" -Recurse -Filter al.exe -ErrorAction SilentlyContinue | % FullName
Get-ChildItem "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\Llvm\bin\clang-cl.exe", "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe" | % FullName
