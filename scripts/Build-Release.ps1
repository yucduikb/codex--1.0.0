[CmdletBinding()]
param([string]$OutputDirectory, [string]$NodePath)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'Package-Common.ps1')
$manifest = Test-DragonPackage $root
& (Join-Path $PSScriptRoot 'Test-Package.ps1') -NodePath $NodePath
if (!$OutputDirectory) { $OutputDirectory = Join-Path $root 'releases' }
$output = Assert-DragonOrdinaryPath $OutputDirectory
New-Item -ItemType Directory -Path $output -Force | Out-Null
$stage = Join-Path $root ('.local\release-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage -Force | Out-Null
foreach ($file in $manifest.files) {
    $destination = Join-Path $stage $file.path
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $root $file.path) -Destination $destination
}
Copy-Item -LiteralPath (Join-Path $root 'package-manifest.json') -Destination $stage
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Write-DragonArchive([string]$Source, [string]$Destination) {
    if (Test-Path -LiteralPath $Destination) { throw "Release already exists; choose a new output directory: $Destination" }
    $zip = [IO.Compression.ZipFile]::Open($Destination,[IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in Get-ChildItem -LiteralPath $Source -Recurse -File -Force) {
            $relative = $file.FullName.Substring($Source.Length + 1).Replace('\','/')
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$file.FullName,$relative,[IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    } finally { $zip.Dispose() }
}
$sourceZip = Join-Path $output ('DragonCodexBoot-' + $manifest.version + '-source.zip')
Write-DragonArchive $stage $sourceZip
$null = & (Join-Path $PSScriptRoot 'Build.ps1') -OutputDirectory $stage
$nodeDir = Join-Path $stage 'engine\runtime\node'
New-Item -ItemType Directory -Path $nodeDir -Force | Out-Null
if ($NodePath) {
    Copy-Item -LiteralPath $NodePath -Destination (Join-Path $nodeDir 'node.exe')
} elseif (Test-Path -LiteralPath (Join-Path $root 'engine\runtime\node\node.exe')) {
    Copy-Item -LiteralPath (Join-Path $root 'engine\runtime\node\node.exe') -Destination $nodeDir
} elseif (Test-Path -LiteralPath (Join-Path $root '.local\test-engine\runtime\node\node.exe')) {
    Copy-Item -LiteralPath (Join-Path $root '.local\test-engine\runtime\node\node.exe') -Destination $nodeDir
}
$node = & (Join-Path $PSScriptRoot 'Ensure-Node.ps1') -EngineRoot (Join-Path $stage 'engine')
$null = Test-DragonPackage $stage
& $node.Path (Join-Path $stage 'tests\PayloadTests.mjs') (Join-Path $stage 'engine\scripts\injector.mjs') (Join-Path $stage 'themes\dragon')
if ($LASTEXITCODE -ne 0) { throw 'Staged offline payload failed verification.' }
$offlineZip = Join-Path $output ('DragonCodexBoot-' + $manifest.version + '-win-x64-offline.zip')
Write-DragonArchive $stage $offlineZip
$lines = foreach ($path in @($sourceZip,$offlineZip)) {
    (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($path)
}
$lines | Set-Content -LiteralPath (Join-Path $output 'SHA256SUMS.txt') -Encoding ASCII
Write-Host ('Release files: ' + $output)
