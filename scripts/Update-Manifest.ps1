[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'Package-Common.ps1')
$files = @(Get-DragonPackageFiles $root | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path=$_.FullName.Substring($root.Length + 1).Replace('\','/'); bytes=$_.Length;
        sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
})
$value = [ordered]@{ schema=1; version=(Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim(); files=$files }
Write-DragonJson (Join-Path $root 'package-manifest.json') $value
Write-Host ("Manifest updated: " + $files.Count + ' files.')
