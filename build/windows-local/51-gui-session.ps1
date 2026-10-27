# Network test, GUI part (interactive session): first start with a fresh profile, Start Center, a Writer
# document typed + saved + reopened, the About box (screenshot + texts), then idle; once with the Thai UI
# (installer default) and once with an English UI profile.
# usage (see run-itask.ps1): 51-gui-session.ps1 <out dir> [idle seconds per run]
param([Parameter(Mandatory)][string]$Out, [int]$Idle = 60)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Drawing, System.Windows.Forms
$A = [Windows.Automation.AutomationElement]; $TS = [Windows.Automation.TreeScope]; $CT = [Windows.Automation.ControlType]
New-Item -ItemType Directory -Force $Out, C:\lo\nettest | Out-Null
$log = "$Out\gui-session.txt"
function Log($s) { "$(Get-Date -Format HH:mm:ss) $s" | Tee-Object -Append $log }
function Screen($name) {
  $b = [Windows.Forms.Screen]::PrimaryScreen.Bounds; $bmp = New-Object Drawing.Bitmap $b.Width, $b.Height
  $g = [Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($b.Location, [Drawing.Point]::Empty, $b.Size); $bmp.Save("$Out\$name.png", 'Png'); $g.Dispose(); $bmp.Dispose()
  Log "screenshot $name.png" }
$dir = (Get-ChildItem 'C:\Program Files' -Recurse -Filter soffice.exe -ErrorAction SilentlyContinue | Where-Object FullName -like '*KanokOffice*' | Select-Object -First 1).DirectoryName
if (-not $dir) { throw 'KanokOffice is not installed' }
$py = "$dir\python.exe"; $client = 'C:\lo\kit\gui-client.py'
$fail = 0
foreach ($ui in 'th', 'en') {
  $prof = "C:\lo\nettest\prof-$ui"; Remove-Item -Recurse -Force $prof -ErrorAction SilentlyContinue
  if ($ui -eq 'en') {
    New-Item -ItemType Directory -Force "$prof\user" | Out-Null
    '<?xml version="1.0" encoding="UTF-8"?><oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><item oor:path="/org.openoffice.Office.Linguistic/General"><prop oor:name="UILocale" oor:op="fuse"><value>en-US</value></prop></item></oor:items>' |
      Set-Content -Encoding UTF8 "$prof\user\registrymodifications.xcu"
  }
  $pipe = "kgui$ui"; $profUrl = 'file:///' + ($prof -replace '\\', '/')
  Log "== UI ${ui}: first start, profile $prof"
  $so = Start-Process "$dir\soffice.exe" -PassThru -ArgumentList @("`"-env:UserInstallation=$profUrl`"", "`"--accept=pipe,name=$pipe;urp;`"")
  Start-Sleep 45; Screen "gui-$ui-1-start"
  & $py $client $pipe write "file:///C:/lo/nettest/doc-$ui.odt" 2>&1 | ForEach-Object { Log "client: $_" }
  Start-Sleep 5; Screen "gui-$ui-2-writer"
  $about = Start-Process $py -PassThru -WindowStyle Hidden -ArgumentList @($client, $pipe, 'about')
  $dlg = $null
  for ($i = 0; $i -lt 60 -and -not $dlg; $i++) {
    Start-Sleep 1
    $dlg = @($A::RootElement.FindAll($TS::Descendants, (New-Object Windows.Automation.PropertyCondition($A::ControlTypeProperty, $CT::Window)))) |
      Where-Object { $_.Current.Name -match '^(About|เกี่ยวกับ)' } | Select-Object -First 1
  }
  if (-not $dlg) { Log 'About box not found'; $fail++ } else {
    Start-Sleep 2; Screen "gui-$ui-3-about"
    $texts = @($dlg.FindAll($TS::Descendants, [Windows.Automation.Condition]::TrueCondition) | ForEach-Object { $_.Current.Name } | Where-Object { $_ })
    [IO.File]::WriteAllLines("$Out\about-$ui-texts.txt", $texts, [Text.UTF8Encoding]::new($true))
    Log "About box '$($dlg.Current.Name)': $($texts.Count) texts (about-$ui-texts.txt)"
    $close = @($dlg.FindAll($TS::Descendants, (New-Object Windows.Automation.PropertyCondition($A::ControlTypeProperty, $CT::Button)))) |
      Where-Object { ($_.Current.Name -replace '[&_~]', '') -match '^(Close|ปิด)$' } | Select-Object -First 1
    if ($close) { $close.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke() } else { [Windows.Forms.SendKeys]::SendWait('{ESC}') }
    $about.WaitForExit(30000) | Out-Null
  }
  Log "idle $Idle s with the document open"; Start-Sleep $Idle; Screen "gui-$ui-4-idle"
  & $py $client $pipe quit 2>&1 | ForEach-Object { Log "client: $_" }
  Start-Sleep 10
  Get-Process soffice* -ErrorAction SilentlyContinue | Stop-Process -Force
}
Log "gui checks failed: $fail"
exit $(if ($fail) { 3 } else { 0 })
