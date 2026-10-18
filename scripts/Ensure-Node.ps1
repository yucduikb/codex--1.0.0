[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$EngineRoot, [switch]$Offline)
$ErrorActionPreference = 'Stop'
$nodeDir = Join-Path $EngineRoot 'runtime\node'
$nodePath = Join-Path $nodeDir 'node.exe'
$expected = 'f8d162c0641dcee512132f3bcf8a68169c7ecb852efd8e1a46c9fec5a0f469ed'
if (!(Test-Path -LiteralPath $nodePath -PathType Leaf)) {
    if ($Offline) { throw 'Offline mode requires engine\runtime\node\node.exe from the full release ZIP.' }
    New-Item -ItemType Directory -Path $nodeDir -Force | Out-Null
    $partial = Join-Path $nodeDir ('node-' + [guid]::NewGuid().ToString('N') + '.download')
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host 'Downloading pinned official Node.js 22.23.1 runtime...'
        $url = 'https://nodejs.org/dist/v22.23.1/node-v22.23.1-win-x64.zip'
        $archiveHash = '7df0bc9375723f4a86b3aa1b7cc73342423d9677a8df4538aca31a049e309c29'
        $systemCurl = Join-Path $env:WINDIR 'System32\curl.exe'
        if (Test-Path -LiteralPath $systemCurl -PathType Leaf) {
            & $systemCurl --fail --location --silent --show-error --proto '=https' --tlsv1.2 `
                --connect-timeout 15 --max-time 180 --retry 1 --retry-max-time 240 --output $partial $url
            if ($LASTEXITCODE -ne 0) { throw 'Official Node.js download failed. Use the offline release ZIP if the network is unavailable.' }
        } else {
            $savedProgress = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            try { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $partial -TimeoutSec 180 }
            finally { $ProgressPreference = $savedProgress }
        }
        if ((Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash -ine $archiveHash) {
            throw 'Official Node.js archive SHA-256 mismatch.'
        }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($partial)
        try {
            $entry = $archive.GetEntry('node-v22.23.1-win-x64/node.exe')
            if (!$entry) { throw 'Official Node.js archive is missing its expected executable.' }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$nodePath,$false)
        } finally { $archive.Dispose() }
    } finally {
        if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial }
    }
}
if ((Get-FileHash -LiteralPath $nodePath -Algorithm SHA256).Hash -ine $expected) {
    throw 'Bundled Node.js differs from the pinned official distribution.'
}
$repoRoot = Split-Path -Parent $PSScriptRoot
Copy-Item -LiteralPath (Join-Path $repoRoot 'licenses\Node.js-LICENSE.txt') -Destination (Join-Path $nodeDir 'LICENSE') -Force
. (Join-Path $EngineRoot 'scripts\common-windows.ps1')
$runtime = Get-DreamSkinValidatedNodeRuntime -Path $nodePath
if ($runtime.Version -ne '22.23.1') { throw 'Unexpected Node.js version.' }
return $runtime
