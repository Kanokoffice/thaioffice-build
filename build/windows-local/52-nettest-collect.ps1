# Network test, end: close the observation window, then two positive controls that must show up
# (the office's python.exe and soffice.bin each fetch https://example.com/), then read the logs.
# usage: 52-nettest-collect.ps1 <out dir>
param([Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
$t0 = [datetime]::Parse((Get-Content "$Out\nettest-t0.txt"), $null, 'RoundtripKind')
$t1 = Get-Date; $t1.ToString('o') | Set-Content "$Out\nettest-t1.txt"
$dir = (Get-ChildItem 'C:\Program Files' -Recurse -Filter soffice.exe -ErrorAction SilentlyContinue | Where-Object FullName -like '*KanokOffice*' | Select-Object -First 1).DirectoryName
Start-Sleep 2
# control 1: the office's Python (a script file: PowerShell 5.1 mangles quotes in -c arguments)
$ErrorActionPreference = 'Continue'
& "$dir\python.exe" C:\lo\kit\net-control.py 2>&1 | Tee-Object "$Out\nettest-control.txt"
# control 2: soffice.bin itself loads a web page
$so = Start-Process "$dir\soffice.exe" -PassThru -ArgumentList @('--headless', '--norestore', '"--accept=pipe,name=knet;urp;"')
& "$dir\python.exe" C:\lo\kit\gui-client.py knet loadurl https://example.com/ 2>&1 | Tee-Object -Append "$Out\nettest-control.txt"
& "$dir\python.exe" C:\lo\kit\gui-client.py knet quit 2>&1 | Out-Null
Start-Sleep 5; Get-Process soffice* -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 5
$ErrorActionPreference = 'Stop'
$t2 = Get-Date
New-Item C:\lo\nettest\stop -ItemType File -Force | Out-Null; Start-Sleep 2
Unregister-ScheduledTask -TaskName kanok-pidwatch -Confirm:$false
$pids = @{}; Get-Content C:\lo\nettest\pids.txt -ErrorAction SilentlyContinue | ForEach-Object { $p = $_ -split ' ', 3; $pids[[int]$p[0]] = $p[2] }
$ev = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 5156, 5157; StartTime = $t0 } -ErrorAction SilentlyContinue
function F($e) { $x = [xml]$e.ToXml(); $h = @{}; $x.Event.EventData.Data | ForEach-Object { $h[$_.Name] = $_.'#text' }; $h }
$rows = foreach ($e in $ev) {
  $d = F $e
  if ($d.Application -like '*\kanokoffice\*' -or $pids.ContainsKey([int]$d.ProcessID)) {
    [pscustomobject]@{ Time = $e.TimeCreated; Id = $e.Id; Pid = [int]$d.ProcessID; App = ($d.Application -replace '^.*\\kanokoffice\\', ''); Dir = $(if ($d.Direction -eq '%%14593') { 'out' } else { 'in' })
      Dest = "$($d.DestAddress):$($d.DestPort)"; Proto = $d.Protocol; Window = $(if ($e.TimeCreated -lt $t1) { 'observed' } else { 'control' }) }
  }
}
$all = @($ev).Count
$dns = Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-DNS-Client/Operational'; Id = 3006; StartTime = $t0 } -ErrorAction SilentlyContinue |
  ForEach-Object { $d = F $_; [pscustomobject]@{ Time = $_.TimeCreated; Pid = [int]$_.ProcessId; Name = $d.QueryName; Window = $(if ($_.TimeCreated -lt $t1) { 'observed' } else { 'control' }) } }
$dnsK = @($dns | Where-Object { $pids.ContainsKey($_.Pid) })
$obs = @($rows | Where-Object { $_.Window -eq 'observed' -and $_.Dest -notmatch '^(127\.|::1|0:0:0:0:0:0:0:1)' })
$ctl = @($rows | Where-Object { $_.Window -eq 'control' -and $_.Dest -notmatch '^(127\.|::1)' })
$report = @(
  "observed window: $($t0.ToString('o')) .. $($t1.ToString('o'))  · controls: .. $($t2.ToString('o'))",
  "KanokOffice process ids seen (polled every 0.5 s): $($pids.Count) · $(@($pids.Values | Sort-Object -Unique | ForEach-Object { Split-Path $_ -Leaf }) -join ', ')",
  "Security 5156/5157 events from all programs since start: $all",
  "connections by KanokOffice programs, observed window, not loopback: $($obs.Count)",
  "connections by KanokOffice programs, observed window, loopback: $(@($rows | Where-Object { $_.Window -eq 'observed' }).Count - $obs.Count)",
  "connections by KanokOffice programs, control window: $($ctl.Count)  (want > 0 for both python.exe and soffice.bin)",
  "  control programs: $(@($ctl | ForEach-Object App | Sort-Object -Unique) -join ', ')",
  "DNS queries by KanokOffice processes: observed $(@($dnsK | Where-Object Window -eq 'observed').Count) · control $(@($dnsK | Where-Object Window -eq 'control').Count)",
  "DNS queries by any process, observed window: $(@($dns | Where-Object Window -eq 'observed').Count)")
$report | Tee-Object "$Out\nettest.txt"
'--- connections (all KanokOffice rows)' | Add-Content "$Out\nettest.txt"
$rows | Sort-Object Time | Format-Table -AutoSize | Out-String -Width 220 | Add-Content "$Out\nettest.txt"
'--- DNS queries by KanokOffice processes' | Add-Content "$Out\nettest.txt"
$dnsK | Sort-Object Time | Format-Table -AutoSize | Out-String -Width 220 | Add-Content "$Out\nettest.txt"
'--- DNS queries by other processes, observed window (names only)' | Add-Content "$Out\nettest.txt"
$dns | Where-Object { $_.Window -eq 'observed' -and -not $pids.ContainsKey($_.Pid) } | Group-Object Name | Sort-Object Count -Descending | ForEach-Object { "$($_.Count) $($_.Name)" } | Add-Content "$Out\nettest.txt"
auditpol /set /subcategory:"{0CCE9226-69AE-11D9-BED3-505054503030}" /success:disable /failure:disable | Out-Null
$ctlApps = @($ctl | ForEach-Object App | Sort-Object -Unique)
$blind = -not (($ctlApps -match 'python') -and ($ctlApps -match 'soffice'))
exit $(if ($blind) { 2 } elseif ($obs.Count -gt 0) { 3 } else { 0 })
