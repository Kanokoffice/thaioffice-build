# Run a long step as a scheduled task (S4U, highest privileges) so it survives the SSH session ending.
# usage: run-task.ps1 <name> <exe> <arguments>   · output: C:\lo\logs\<name>.out · exit code: C:\lo\logs\<name>.rc
param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Exe, [string]$Arguments = '')
$ErrorActionPreference = 'Stop'
$out = "C:\lo\logs\$Name.out"; $rc = "C:\lo\logs\$Name.rc"
Remove-Item $rc -ErrorAction SilentlyContinue
$wrap = "C:\lo\logs\$Name.cmd"
"@echo off`r`ncd /d C:\lo`r`n`"$Exe`" $Arguments > `"$out`" 2>&1`r`necho %ERRORLEVEL% > `"$rc`"`r`n" | Set-Content -Encoding ascii $wrap
$act = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c `"$wrap`""
$pri = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType S4U -RunLevel Highest
$set = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 12) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "kanok-$Name" -Action $act -Principal $pri -Settings $set -Force | Out-Null
Start-ScheduledTask -TaskName "kanok-$Name"
"started kanok-$Name -> $out"
