# Network test, start: log every connection Windows Filtering Platform allows or blocks (Security log
# 5156/5157, with the program path), DNS queries (DNS Client log, by process id), and the ids of every
# process running from the KanokOffice folder. Run before the install test; 52-nettest-collect.ps1 reads them.
# usage: 50-nettest-start.ps1 <out dir>
param([Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $Out | Out-Null
wevtutil sl Security /ms:536870912
auditpol /set /subcategory:"{0CCE9226-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable | Out-Null   # Filtering Platform Connection
auditpol /get /subcategory:"{0CCE9226-69AE-11D9-BED3-505054503030}" | Tee-Object "$Out\nettest-audit.txt"
wevtutil sl Microsoft-Windows-DNS-Client/Operational /e:true /ms:104857600
wevtutil cl Microsoft-Windows-DNS-Client/Operational
Clear-DnsClientCache
# process ids: a polling task in the background until C:\lo\nettest\stop exists
New-Item -ItemType Directory -Force C:\lo\nettest | Out-Null; Remove-Item C:\lo\nettest\stop, C:\lo\nettest\pids.txt -ErrorAction SilentlyContinue
$watch = 'while (-not (Test-Path C:\lo\nettest\stop)) { Get-Process | Where-Object { $_.Path -like ''*\KanokOffice\*'' } | ForEach-Object { "$($_.Id) $($_.ProcessName) $($_.Path)" } | Add-Content C:\lo\nettest\pids.txt; Start-Sleep -Milliseconds 500 }'
Set-Content -Encoding ascii C:\lo\nettest\pidwatch.ps1 $watch
$act = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\lo\nettest\pidwatch.ps1'
$pri = New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName kanok-pidwatch -Action $act -Principal $pri -Force | Out-Null
Start-ScheduledTask -TaskName kanok-pidwatch
$t0 = Get-Date
$t0.ToString('o') | Set-Content "$Out\nettest-t0.txt"
"network test started $($t0.ToString('o'))"
