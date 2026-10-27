# License page in the built MSI: tables of the installer database (en-US base) and of the per-language databases.
# usage: 45-check-eula.ps1 <msi> <expected rtf> <out dir> [per-language msi ...]
param([Parameter(Mandatory)][string]$Msi, [Parameter(Mandatory)][string]$Rtf, [Parameter(Mandatory)][string]$Out, [string[]]$Lang = @())
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $Out | Out-Null
$inst = New-Object -ComObject WindowsInstaller.Installer
function Call($o, $m, $a) { $o.GetType().InvokeMember($m, 'InvokeMethod', $null, $o, $a) }
function Prop($o, $m, $a) { $o.GetType().InvokeMember($m, 'GetProperty', $null, $o, $a) }
function Rows($db, $sql, $n) {
  $v = Call $db 'OpenView' @([string]$sql); Call $v 'Execute' @() | Out-Null; $r = @()
  while ($rec = Call $v 'Fetch' @()) { $r += ,(@(1..$n | % { Prop $rec 'StringData' @([int]$_) }) -join ' | ') }
  Call $v 'Close' @() | Out-Null; $r }
# expected Memo text: what the packager puts there (each line without trailing blanks, followed by one space)
$want = ((Get-Content $Rtf -Encoding ASCII | % { $_.TrimEnd() + ' ' }) -join '')
$db0 = Call $inst 'OpenDatabase' @([string]$Msi, [int]0)
$storages = @(Rows $db0 'SELECT `Name` FROM `_Storages`' 1)
"embedded storages (language transforms): $($storages -join ', ')" | Tee-Object "$Out\eula-tables.txt"
# msidb here cannot write a storage out, so a transform is checked through the per-language database the packager
# built it from (idt_files\<langs>\<lang>\*.msi: the transform is that database minus the base one); the wizard
# test (46-eula-ui.ps1 with TRANSFORMS=:1054) then uses the embedded transform itself
$fail = 0
foreach ($t in @('') + $Lang) {
  $db = if ($t) { Call $inst 'OpenDatabase' @([string]$t, [int]0) } else { $db0 }
  $name = if ($t) { "language database $([IO.Path]::GetFileName($t))" } else { 'installer (en-US base)' }
  $agree = @(Rows $db "SELECT ``Control``,``Type``,``Property``,``Text`` FROM ``Control`` WHERE ``Dialog_``='LicenseAgreement' AND ``Control``='Agree'" 4)
  $memoV = Call $db 'OpenView' @([string]"SELECT ``Text`` FROM ``Control`` WHERE ``Dialog_``='LicenseAgreement' AND ``Control``='Memo'")
  Call $memoV 'Execute' @() | Out-Null; $memo = Prop (Call $memoV 'Fetch' @()) 'StringData' @([int]1); Call $memoV 'Close' @() | Out-Null
  $title = @(Rows $db "SELECT ``Text`` FROM ``Control`` WHERE ``Dialog_``='LicenseAgreement' AND (``Control``='DlgTitle' OR ``Control``='DlgDesc')" 1)
  $cb = @(Rows $db "SELECT ``Property``,``Value`` FROM ``CheckBox`` WHERE ``Property``='AgreeToLicense'" 2)
  $pr = @(Rows $db "SELECT ``Property``,``Value`` FROM ``Property`` WHERE ``Property``='AgreeToLicense' OR ``Property``='HIDEEULA'" 2)
  $cc = @(Rows $db "SELECT ``Action``,``Condition`` FROM ``ControlCondition`` WHERE ``Dialog_``='LicenseAgreement' AND ``Control_``='Next'" 2)
  $ce = @(Rows $db "SELECT ``Dialog_``,``Control_``,``Argument``,``Condition`` FROM ``ControlEvent`` WHERE ``Control_``='Next' AND (``Dialog_``='InstallWelcome' OR ``Dialog_``='LicenseAgreement')" 4)
  $memoOk = ($memo -ceq $want)
  $ok = ($agree.Count -eq 1 -and $agree[0] -like 'Agree | CheckBox | AgreeToLicense | *') -and ($cb -contains 'AgreeToLicense | Yes') -and ($pr.Count -eq 0) -and $memoOk
  if (-not $ok) { $fail++ }
  @("== $name", "Agree: $agree", "title / desc: $($title -join ' / ')", "CheckBox: $cb", "Property AgreeToLicense or HIDEEULA (want none): $($pr -join '; ')",
    "Next conditions: $($cc -join '; ')", "Next events: $($ce -join '; ')",
    "Memo: $($memo.Length) chars, identical to $([IO.Path]::GetFileName($Rtf)) as packed: $memoOk", "result: $(if ($ok) {'ok'} else {'FAIL'})") | Tee-Object -Append "$Out\eula-tables.txt"
}
"tables failed: $fail" | Tee-Object -Append "$Out\eula-tables.txt"
exit $(if ($fail) { 3 } else { 0 })
