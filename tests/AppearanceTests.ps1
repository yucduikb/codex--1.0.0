$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $repoRoot 'engine\scripts\common-windows.ps1')
$fixture = Join-Path $repoRoot ('.local\a-' + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $fixture -Force | Out-Null
$config = Join-Path $fixture 'config.toml'
$backup = Join-Path $fixture 'before.toml'
$original = "model = `"fixture-model`"`r`n[desktop]`r`nappearanceTheme = `"dark`"`r`n"
$original | Set-Content -LiteralPath $config -Encoding UTF8 -NoNewline
$transaction = Install-DreamSkinBaseTheme -ConfigPath $config -BackupPath $backup -AppearanceTheme light -PassThruTransaction
$undo = Join-Path $fixture 'undo.clixml'
$transaction | Export-Clixml -LiteralPath $undo -Depth 30
Complete-DreamSkinAppearanceTransaction -BackupPath $backup -Transaction $transaction
$transaction = Import-Clixml -LiteralPath $undo
$installed = Get-Content -LiteralPath $config -Encoding UTF8 -Raw
if ($installed -notmatch 'appearanceTheme = "light"') { throw 'Light appearance was not applied.' }
# Change an unrelated model value and one managed value after installation.
$installed.Replace('fixture-model','changed-model').Replace('appearanceLightCodeThemeId = "codex"','appearanceLightCodeThemeId = "user-theme"') |
    Set-Content -LiteralPath $config -Encoding UTF8 -NoNewline
$result = Restore-DreamSkinManagedAppearanceSnapshot -ConfigPath $config -BackupPath $backup -Transaction $transaction
$restored = Get-Content -LiteralPath $config -Encoding UTF8 -Raw
if ($restored -notmatch 'appearanceTheme = "dark"' -or $restored -notmatch 'changed-model' -or
    $restored -notmatch 'appearanceLightCodeThemeId = "user-theme"' -or
    $result.ConflictedKeys -notcontains 'appearanceLightCodeThemeId') {
    throw 'Appearance restoration lost a user change or failed to restore an owned key.'
}
Write-Output 'PASS: appearance install, persisted undo, owned-key restore and concurrent user edits preserved.'
