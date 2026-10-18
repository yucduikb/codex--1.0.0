[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'Package-Common.ps1')
. (Join-Path $root 'engine\scripts\common-windows.ps1')
. (Join-Path $root 'engine\scripts\theme-windows.ps1')
$marker = Get-Content -LiteralPath (Join-Path $root 'install-state.json') -Encoding UTF8 -Raw | ConvertFrom-Json
if ($marker.product -ne 'DragonCodexBoot-Community' -or !(Test-DreamSkinPathEqual $marker.installDir $root)) {
    throw 'Run uninstall from the installed directory.'
}
$skinRoot = Join-Path $root 'skin'
$skinState = Read-DreamSkinState -Path (Join-Path $skinRoot 'state.json')
Set-DreamSkinPaused -Paused $true -StateRoot $skinRoot | Out-Null
if (!(Stop-DreamSkinRecordedInjector -State $skinState)) { throw 'Could not verify the recorded wallpaper watcher; no other processes were stopped.' }
if (Test-Path -LiteralPath (Join-Path $root '.integration\entrypoints-state.json')) {
    $null = & (Join-Path $PSScriptRoot 'integrate-entrypoints.ps1') -Action Restore -AppRoot $root
    $report = Get-Content -LiteralPath (Join-Path $root '.integration\report.json') -Encoding UTF8 -Raw | ConvertFrom-Json
    if ($report.Errors.Count) { throw 'Some shortcuts could not be restored. See .integration\report.json.' }
}
$undo = Join-Path $skinRoot 'appearance-undo.clixml'
if (Test-Path -LiteralPath $undo) {
    $transaction = Import-Clixml -LiteralPath $undo
    $result = Restore-DreamSkinManagedAppearanceSnapshot -ConfigPath $marker.configPath -BackupPath $marker.backupPath -Transaction $transaction
    if ($result.ConflictedKeys.Count) { Write-Warning ('Preserved settings edited since installation: ' + ($result.ConflictedKeys -join ', ')) }
}
$marker | Add-Member -NotePropertyName uninstalledAt -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('o')) -Force
Write-DragonJson (Join-Path $root 'install-state.json') $marker
Write-Host 'Shortcuts and managed appearance restored. Save your work, fully quit Codex, then reopen it to clear the injected wallpaper; closing a window may leave background processes.'
Write-Host ("Installation files, profile and backups were retained: " + $root)
Write-Host 'After restarting Codex, you may remove this installation folder manually if it is no longer needed.'
