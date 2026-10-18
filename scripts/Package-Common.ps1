$ErrorActionPreference = 'Stop'

function Write-DragonJson([string]$Path, $Value) {
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $temp = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        $Value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $temp -Encoding UTF8
        Move-Item -LiteralPath $temp -Destination $Path -Force
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp }
    }
}

function Assert-DragonOrdinaryPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $part = $full
    while ($part) {
        if (Test-Path -LiteralPath $part) {
            if (([IO.File]::GetAttributes($part) -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Reparse points are not supported for deployment: $part"
            }
        }
        $parent = Split-Path -Parent $part
        if ($parent -eq $part) { break }
        $part = $parent
    }
    return $full
}

function Get-DragonPackageFiles([string]$Root) {
    $top = @('src','scripts','config','media','themes','licenses','tests','docs','tools','.github')
    $leaves = @('Install.ps1','Install.cmd','Uninstall.cmd','README.md','AGENTS.md',
        'DEPLOY_WITH_GPT.md','LICENSE','THIRD_PARTY_NOTICES.md','VERSION','.gitignore','.gitattributes')
    foreach ($name in $leaves) {
        $path = Join-Path $Root $name
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing package file: $name" }
        Get-Item -LiteralPath $path
    }
    foreach ($name in $top + @('engine\assets','engine\scripts')) {
        $dir = Join-Path $Root $name
        if (!(Test-Path -LiteralPath $dir -PathType Container)) { throw "Missing package directory: $name" }
        Get-ChildItem -LiteralPath $dir -File -Recurse
    }
}

function Test-DragonPackage([string]$Root) {
    $manifest = Get-Content -LiteralPath (Join-Path $Root 'package-manifest.json') -Encoding UTF8 -Raw | ConvertFrom-Json
    if ($manifest.schema -ne 1 -or $manifest.files.Count -lt 20) { throw 'Invalid package manifest.' }
    $seen = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in $manifest.files) {
        $relative = [string]$file.path
        if (!$relative -or [IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)|[:\x00]') {
            throw 'Invalid package manifest path.'
        }
        if (!$seen.Add($relative.Replace('\','/'))) { throw 'Duplicate package manifest path.' }
        $path = Assert-DragonOrdinaryPath (Join-Path $Root $relative)
        if (!(Test-Path -LiteralPath $path -PathType Leaf) -or
            (Get-Item -LiteralPath $path).Length -ne $file.bytes -or
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine $file.sha256) {
            throw "Package integrity check failed: $relative. Extract the complete package again."
        }
    }
    # Reject unlisted executable source files in the payload directories.
    foreach ($file in @(Get-DragonPackageFiles $Root)) {
        $relative = $file.FullName.Substring($Root.TrimEnd('\','/').Length + 1).Replace('\','/')
        if (!$seen.Contains($relative)) { throw "Unlisted package file: $relative" }
    }
    return $manifest
}
