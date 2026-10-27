# Run a step in this user's interactive (console) session with highest privileges, and wait for it.
# usage: run-itask.ps1 <name> <exe> <arguments> [timeout minutes]   · output: C:\lo\logs\<name>.out · exit code: <name>.rc
param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Exe, [string]$Arguments = '', [int]$Minutes = 20)
$ErrorActionPreference = 'Stop'
$out = "C:\lo\logs\$Name.out"; $rc = "C:\lo\logs\$Name.rc"; Remove-Item $rc -ErrorAction SilentlyContinue
$wrap = "C:\lo\logs\$Name.cmd"
"@echo off`r`ncd /d C:\lo`r`n`"$Exe`" $Arguments > `"$out`" 2>&1`r`necho %ERRORLEVEL% > `"$rc`"`r`n" | Set-Content -Encoding ascii $wrap
$act = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c `"$wrap`""
$pri = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
$set = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes $Minutes) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "kanok-$Name" -Action $act -Principal $pri -Settings $set -Force | Out-Null
Start-ScheduledTask -TaskName "kanok-$Name"
$t = [Diagnostics.Stopwatch]::StartNew()
while (-not (Test-Path $rc) -and $t.Elapsed.TotalMinutes -lt $Minutes) { Start-Sleep 2 }
if (Test-Path $out) { Get-Content $out -Encoding UTF8 }
if (Test-Path $rc) { "rc=$((Get-Content $rc).Trim())" } else { 'rc=timeout' }
