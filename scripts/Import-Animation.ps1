[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$VideoPath,[string]$AppRoot)
$ErrorActionPreference = 'Stop'
if (!$AppRoot) {
    $parent = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    if (Test-Path -LiteralPath (Join-Path $parent 'DragonCodexBoot.exe')) { $AppRoot = $parent }
    else { $AppRoot = Join-Path $parent 'build/DragonCodexBoot' }
}
$AppRoot = [IO.Path]::GetFullPath($AppRoot)
$source = (Resolve-Path -LiteralPath $VideoPath).Path
if ([IO.Path]::GetExtension($source) -ine '.mp4') { throw 'Provide an MP4 file.' }
if (!(Test-Path -LiteralPath (Join-Path $AppRoot 'DragonCodexBoot.exe'))) { throw 'Build or extract the launcher first.' }
$configPath = Join-Path $AppRoot 'launcher.json'
$config = Get-Content -LiteralPath $configPath -Encoding UTF8 -Raw | ConvertFrom-Json
$mediaRoot = Join-Path $AppRoot 'media'
$destination = Join-Path $mediaRoot 'startup.mp4'
New-Item -ItemType Directory -Path $mediaRoot -Force | Out-Null
if (![string]::Equals($source,$destination,[StringComparison]::OrdinalIgnoreCase)) {
    if (Test-Path -LiteralPath $destination) {
        $backup = Join-Path $mediaRoot ('startup-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N') + '.mp4')
        Copy-Item -LiteralPath $destination -Destination $backup
        if ((Get-FileHash -LiteralPath $destination).Hash -ne (Get-FileHash -LiteralPath $backup).Hash) { throw 'Media backup mismatch.' }
    }
    Copy-Item -LiteralPath $source -Destination $destination -Force
    if ((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $destination).Hash) { throw 'Media copy mismatch.' }
}
$configBackup = $configPath + '.backup-' + [Guid]::NewGuid().ToString('N')
Copy-Item -LiteralPath $configPath -Destination $configBackup
if ((Get-FileHash -LiteralPath $configPath).Hash -ne (Get-FileHash -LiteralPath $configBackup).Hash) { throw 'Config backup mismatch.' }
$config.Video = 'media/startup.mp4'
$config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configPath -Encoding UTF8
Write-Output ('Imported: ' + $destination)
Write-Output 'Adjust HoldAt, TransitionStart, TransitionEnd and ScreenFrames for your video. Run tests before launching.'
