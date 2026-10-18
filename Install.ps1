[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'DragonCodexBoot-Community'),
    [switch]$Offline,
    [switch]$Portable,
    [switch]$NoShortcuts,
    [switch]$NoAppearance,
    [switch]$Launch
)
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath($PSScriptRoot)
. (Join-Path $repoRoot 'scripts\Package-Common.ps1')
if (![Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
    throw 'This package supports Windows x64. ARM64 is not tested.'
}
$target = (Assert-DragonOrdinaryPath $InstallDir).TrimEnd('\','/')
if ($target -eq $repoRoot -or $target.StartsWith($repoRoot + '\',[StringComparison]::OrdinalIgnoreCase) -or
    $repoRoot.StartsWith($target + '\',[StringComparison]::OrdinalIgnoreCase) -or
    $target -eq [IO.Path]::GetPathRoot($target).TrimEnd('\')) {
    throw 'Choose an installation folder separate from the source repository and filesystem roots.'
}
if ((Test-Path -LiteralPath $target) -and @(Get-ChildItem -LiteralPath $target -Force).Count -gt 0 -and
    !(Test-Path -LiteralPath (Join-Path $target 'install-state.json'))) {
    throw 'The destination is not an existing managed installation. Choose an empty directory.'
}
$manifest = Test-DragonPackage $repoRoot
. (Join-Path $repoRoot 'engine\scripts\common-windows.ps1')
$codex = if (!$Portable) { Get-DreamSkinCodexInstall } else { $null }
$existingState = if (Test-Path -LiteralPath (Join-Path $target 'install-state.json')) {
    Get-Content -LiteralPath (Join-Path $target 'install-state.json') -Encoding UTF8 -Raw | ConvertFrom-Json
} else { $null }
if ($existingState -and ($existingState.product -ne 'DragonCodexBoot-Community' -or
    !(Test-DreamSkinPathEqual $existingState.installDir $target))) { throw 'Installation marker is invalid.' }
if (@(Get-Process -Name DragonCodexBoot -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -and (Test-DreamSkinPathEqual $_.Path (Join-Path $target 'DragonCodexBoot.exe'))
}).Count -gt 0) { throw 'Wait for the current startup animation to finish, then install again.' }

# Prepare all files before changing appearance or shortcuts.
$stage = Join-Path $repoRoot ('.local\install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage -Force | Out-Null
foreach ($dir in @('scripts','engine','themes','media','licenses')) {
    New-Item -ItemType Directory -Path (Join-Path $stage $dir) -Force | Out-Null
}
foreach ($file in $manifest.files) {
    if ($file.path -match '^(scripts|engine|themes|media|licenses)/' -or
        $file.path -in @('LICENSE','THIRD_PARTY_NOTICES.md','VERSION','Uninstall.cmd')) {
        $destination = Join-Path $stage $file.path
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $repoRoot $file.path) -Destination $destination -Force
    }
}
$bundledNode = Join-Path $repoRoot 'engine\runtime\node\node.exe'
if (Test-Path -LiteralPath $bundledNode) {
    $nodeDir = Join-Path $stage 'engine\runtime\node'
    New-Item -ItemType Directory -Path $nodeDir -Force | Out-Null
    Copy-Item -LiteralPath $bundledNode -Destination $nodeDir
}
$node = & (Join-Path $repoRoot 'scripts\Ensure-Node.ps1') -EngineRoot (Join-Path $stage 'engine') -Offline:$Offline
& $node.Path (Join-Path $repoRoot 'tests\PayloadTests.mjs') (Join-Path $stage 'engine\scripts\injector.mjs') (Join-Path $stage 'themes\dragon')
if ($LASTEXITCODE -ne 0) { throw 'Wallpaper payload validation failed; no shortcuts were changed.' }
$null = & (Join-Path $repoRoot 'scripts\Build.ps1') -OutputDirectory $stage
$cfg = Get-Content -LiteralPath (Join-Path $stage 'launcher.json') -Encoding UTF8 -Raw | ConvertFrom-Json
if ($codex) { $cfg.AppLaunch = 'shell:AppsFolder\' + $codex.AppUserModelId }
Write-DragonJson (Join-Path $stage 'launcher.json') $cfg

New-Item -ItemType Directory -Path $target -Force | Out-Null
if ($existingState) {
    # Preserve the complete previous managed payload; profiles/state are never replaced.
    $backup = Join-Path $target ('backups\payload-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    foreach ($name in @('scripts','engine','themes','media','licenses','DragonCodexBoot.exe','launcher.json','install-state.json','Uninstall.cmd')) {
        if (Test-Path -LiteralPath (Join-Path $target $name)) { Copy-Item -LiteralPath (Join-Path $target $name) -Destination $backup -Recurse }
    }
    $priorWatcher = Read-DreamSkinState -Path (Join-Path $target 'skin\state.json')
    if (!(Stop-DreamSkinRecordedInjector -State $priorWatcher)) { throw 'Cannot safely stop the recorded watcher for update.' }
}
foreach ($item in Get-ChildItem -LiteralPath $stage -Force) {
    if ($item.PSIsContainer) {
        $destination = Join-Path $target $item.Name
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        Get-ChildItem -LiteralPath $item.FullName -Force | Copy-Item -Destination $destination -Recurse -Force
    } else { Copy-Item -LiteralPath $item.FullName -Destination $target -Force }
}
$skinRoot = Join-Path $target 'skin'
New-Item -ItemType Directory -Path $skinRoot -Force | Out-Null
$state = [ordered]@{ product='DragonCodexBoot-Community'; schema=1; version=$manifest.version;
    installDir=$target; installedAt=(Get-Date).ToUniversalTime().ToString('o'); portable=[bool]$Portable;
    configPath=$null; backupPath=$null }
if ($existingState) { $state.configPath=$existingState.configPath; $state.backupPath=$existingState.backupPath }
# Save a recovery marker before changes to external appearance/shortcuts.
Write-DragonJson (Join-Path $target 'install-state.json') $state
if (!$Portable -and !$NoAppearance -and
    (!(Test-Path -LiteralPath (Join-Path $skinRoot 'appearance-undo.clixml')) -or ($existingState -and $existingState.uninstalledAt))) {
    $paths = Resolve-DreamSkinConfigPaths -StateRoot $skinRoot -BindBackup
    $state.configPath=$paths.ConfigPath; $state.backupPath=$paths.BackupPath
    Write-DragonJson (Join-Path $target 'install-state.json') $state
    $transaction = Install-DreamSkinBaseTheme -ConfigPath $paths.ConfigPath -BackupPath $paths.BackupPath -AppearanceTheme light -PassThruTransaction
    $transaction | Export-Clixml -LiteralPath (Join-Path $skinRoot 'appearance-undo.clixml') -Depth 30
    Complete-DreamSkinAppearanceTransaction -BackupPath $paths.BackupPath -Transaction $transaction
}
if (!$Portable -and !$NoShortcuts) {
    $null = & (Join-Path $target 'scripts\integrate-entrypoints.ps1') -Action Install -AppRoot $target -OfficialExecutablePaths @($codex.Executable) -ScanBudgetSeconds 30
    $report = Get-Content -LiteralPath (Join-Path $target '.integration\report.json') -Encoding UTF8 -Raw | ConvertFrom-Json
    if ($report.Errors.Count -gt 0 -or ($report.Replaced + $report.Created + $report.AlreadyOwned) -eq 0) {
        throw "Payload installed, but shortcut setup needs attention. See $target\.integration\report.json"
    }
}
Write-Host ("Installed: " + $target)
if ($Portable -or $NoShortcuts) {
    Write-Host ('Prepared launcher: ' + (Join-Path $target 'DragonCodexBoot.exe'))
} else {
    Write-Host 'Open Codex from the Desktop/Start Menu shortcut after installation. Existing taskbar pins may need repinning.'
}
if ($Launch) { Start-Process -FilePath (Join-Path $target 'DragonCodexBoot.exe') -WorkingDirectory $target }
