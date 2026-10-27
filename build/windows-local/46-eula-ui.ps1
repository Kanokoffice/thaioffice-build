# Walk the MSI wizard to the license page in the interactive session and check that Next only works once
# the box is ticked; screenshots and the text the page shows. Cancels before anything is installed.
# The installer's controls show up in UI Automation only as panes (class Button / RichEdit20W), so they are
# driven with plain window messages: BM_CLICK, BM_GETCHECK, IsWindowEnabled, WM_GETTEXT.
# usage (interactive task, see run-itask.ps1): 46-eula-ui.ps1 <msi> <out dir> [transform, e.g. :1054]
param([Parameter(Mandatory)][string]$Msi, [Parameter(Mandatory)][string]$Out, [string]$Transform = '')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Drawing
Add-Type -Namespace K -Name W -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, int m, IntPtr w, IntPtr l);
[DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "SendMessageW")] public static extern IntPtr SendText(IntPtr h, int m, IntPtr w, System.Text.StringBuilder l);
[DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
'@
$AE = [Windows.Automation.AutomationElement]; $TS = [Windows.Automation.TreeScope]
$tag = if ($Transform) { $Transform.TrimStart(':') } else { 'base' }
New-Item -ItemType Directory -Force $Out | Out-Null
$log = "$Out\eula-ui-$tag.txt"; Remove-Item $log -ErrorAction SilentlyContinue
function Log($s) { "$(Get-Date -Format HH:mm:ss) $s" | Tee-Object -Append $log }
function Shot($el, $name) {
  $r = $el.Current.BoundingRectangle; $bmp = New-Object Drawing.Bitmap ([int]$r.Width), ([int]$r.Height)
  $g = [Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen([int]$r.X, [int]$r.Y, 0, 0, $bmp.Size); $bmp.Save("$Out\$name.png", 'Png'); $g.Dispose(); $bmp.Dispose()
  Log "screenshot $name.png" }
function Windows() { @($AE::RootElement.FindAll($TS::Children, (New-Object Windows.Automation.PropertyCondition($AE::ProcessIdProperty, $proc.Id)))) }
function Wizard() { Windows | Where-Object { $_.Current.Name -match 'KanokOffice' } | Select-Object -First 1 }
function Ctl($win, $class, $re) { @($win.FindAll($TS::Descendants, [Windows.Automation.Condition]::TrueCondition)) |
  Where-Object { $_.Current.ClassName -match $class -and ($_.Current.Name -replace '&', '') -match $re } | Select-Object -First 1 }
function Hwnd($el) { [IntPtr]$el.Current.NativeWindowHandle }
function Click($el) { [K.W]::SendMessage((Hwnd $el), 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null }            # BM_CLICK
function Checked($el) { [int][K.W]::SendMessage((Hwnd $el), 0x00F0, [IntPtr]::Zero, [IntPtr]::Zero) -eq 1 }          # BM_GETCHECK
function Enabled($el) { [K.W]::IsWindowEnabled((Hwnd $el)) }
function WaitFor($what, [scriptblock]$probe, $sec = 120) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt $sec) { $x = & $probe; if ($x) { return $x }; Start-Sleep -Milliseconds 500 }
  throw "timeout waiting for $what" }
$reNext = '^(Next|ถัดไป) >$'
$margs = @('/i', "`"$Msi`"", '/l*v', "`"$Out\eula-ui-$tag-msiexec.log`"") + $(if ($Transform) { @("TRANSFORMS=$Transform") } else { @() })
$proc = Start-Process msiexec.exe -PassThru -ArgumentList $margs
Log "msiexec pid $($proc.Id) $($margs -join ' ')"
$fail = 0
try {
  # welcome page: Next enabled and no rich edit box on the page
  $next = WaitFor 'welcome page' { $w = Wizard; if ($w -and -not (Ctl $w '(?i)richedit' '.*')) { $b = Ctl $w '^Button$' $reNext; if ($b -and (Enabled $b)) { $b } } }
  Start-Sleep 1; $win = Wizard; [K.W]::SetForegroundWindow((Hwnd $win)) | Out-Null; Shot $win "eula-$tag-1-welcome"
  Click $next
  $memo = WaitFor 'license page' { $w = Wizard; if ($w) { Ctl $w '(?i)richedit' '.*' } }
  Start-Sleep 2; $win = Wizard; [K.W]::SetForegroundWindow((Hwnd $win)) | Out-Null
  $all = @($win.FindAll($TS::Descendants, [Windows.Automation.Condition]::TrueCondition))
  Log "controls on the page: $(@($all | ForEach-Object { "$($_.Current.ClassName):'$($_.Current.Name)'" }) -join ' | ')"
  $next = Ctl $win '^Button$' $reNext
  $box = $all | Where-Object { $_.Current.ClassName -eq 'Button' -and ($_.Current.Name -replace '&', '') -match 'accept|ยอมรับ' } | Select-Object -First 1
  if (-not $box) { throw 'no accept check box on the license page' }
  Log "check box: '$($box.Current.Name)'"
  $s0 = Checked $box; $e0 = Enabled $next
  Log "before ticking: ticked=$s0 Next enabled=$e0 (want False / False)"; if ($s0 -or $e0) { $fail++ }
  Shot $win "eula-$tag-2-license-unticked"
  # Next must also do nothing while unticked
  Click $next; Start-Sleep 2
  $still = [bool](Ctl (Wizard) '(?i)richedit' '.*')
  Log "clicked Next while unticked: still on the license page=$still (want True)"; if (-not $still) { $fail++ }
  # the text in the box
  $len = [int][K.W]::SendMessage((Hwnd $memo), 0x000E, [IntPtr]::Zero, [IntPtr]::Zero)                                   # WM_GETTEXTLENGTH
  $sb = New-Object Text.StringBuilder ($len + 1); [K.W]::SendText((Hwnd $memo), 0x000D, [IntPtr]($len + 1), $sb) | Out-Null  # WM_GETTEXT
  [IO.File]::WriteAllText("$Out\eula-$tag-shown-text.txt", $sb.ToString(), [Text.UTF8Encoding]::new($true))
  Log "text in the box: $($sb.Length) chars (eula-$tag-shown-text.txt)"
  Click $box; Start-Sleep 1
  $s1 = Checked $box; $e1 = Enabled $next
  Log "after ticking: ticked=$s1 Next enabled=$e1 (want True / True)"; if (-not $s1 -or -not $e1) { $fail++ }
  Shot $win "eula-$tag-3-license-ticked"
  Click $box; Start-Sleep 1
  $s2 = Checked $box; $e2 = Enabled $next
  Log "after unticking: ticked=$s2 Next enabled=$e2 (want False / False)"; if ($s2 -or $e2) { $fail++ }
  # tick again and go one page on, to show Next really leads on; then cancel there
  Click $box; Start-Sleep 1; Click $next
  $moved = WaitFor 'page after the license page' { $w = Wizard; if ($w -and -not (Ctl $w '(?i)richedit' '.*')) { $w } } 30
  Start-Sleep 1; Shot $moved "eula-$tag-4-next-page"
  Click (Ctl (Wizard) '^Button$' '^(Cancel|ยกเลิก)$')
  Click (WaitFor 'cancel confirmation' { foreach ($w in Windows) { $b = Ctl $w '^Button$' '^(Yes|ใช่)$'; if ($b) { return $b } } } 30)
  Click (WaitFor 'finish button' { $w = Wizard; if ($w) { Ctl $w '^Button$' '^(Finish|เสร็จสิ้น)$' } } 60)
  $proc.WaitForExit(60000) | Out-Null
  Log "msiexec exit $($proc.ExitCode) (1602 = cancelled by the user)"
} catch {
  Log "ERROR $_"; $fail++
  try { $w = Wizard; if ($w) { Shot $w "eula-$tag-error" } } catch {}
  Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
}
Log "checks failed: $fail"
exit $(if ($fail) { 3 } else { 0 })
