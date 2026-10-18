[CmdletBinding()]
param([string]$NodePath)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'Package-Common.ps1')
$manifest = Test-DragonPackage $root
$parseCount = 0
foreach ($file in $manifest.files | Where-Object { $_.path -like '*.ps1' }) {
    $tokens=$null; $errors=$null
    $null = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root $file.path),[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw ($errors | Out-String) }
    $parseCount++
}
$exe = & (Join-Path $PSScriptRoot 'Build.ps1')
$build = Split-Path -Parent $exe
$process = Start-Process -FilePath $exe -ArgumentList '--self-test' -Wait -PassThru -WindowStyle Hidden
if ($process.ExitCode -ne 0) { throw 'Launcher self-test failed.' }
$selfTest = Get-Content -LiteralPath (Join-Path $build 'qa\self-test.json') -Encoding UTF8 -Raw | ConvertFrom-Json
if (!$selfTest.ok -or $selfTest.geometryCases -ne 605 -or $selfTest.fixedPlacementCases -ne 12) { throw 'Unexpected launcher self-test results.' }
& (Join-Path $root 'tests\Test-StartupIdentity.ps1') -AppRoot $build
& (Join-Path $root 'tests\EntrypointTests.ps1')
& (Join-Path $root 'tests\AppearanceTests.ps1')
. (Join-Path $root 'engine\scripts\common-windows.ps1')
if ($NodePath) {
    $runtime = Get-DreamSkinValidatedNodeRuntime -Path $NodePath
} else {
    $bundled = Join-Path $root 'engine\runtime\node\node.exe'
    if (!(Test-Path -LiteralPath $bundled)) {
        $cacheEngine = Join-Path $root '.local\test-engine'
        New-Item -ItemType Directory -Path $cacheEngine -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $root 'engine\scripts') -Destination $cacheEngine -Recurse -Force
        $runtime = & (Join-Path $PSScriptRoot 'Ensure-Node.ps1') -EngineRoot $cacheEngine
    } else {
        $runtime = & (Join-Path $PSScriptRoot 'Ensure-Node.ps1') -EngineRoot (Join-Path $root 'engine') -Offline
    }
}
foreach ($file in $manifest.files | Where-Object { $_.path -match '\.(mjs|js)$' }) {
    & $runtime.Path --check (Join-Path $root $file.path)
    if ($LASTEXITCODE -ne 0) { throw "JavaScript parse failure: $($file.path)" }
}
$env:DREAMSKIN_COMPAT_PROFILE = '0'
& $runtime.Path (Join-Path $root 'tests\PayloadTests.mjs') (Join-Path $root 'engine\scripts\injector.mjs') (Join-Path $root 'themes\dragon')
if ($LASTEXITCODE -ne 0) { throw 'Video wallpaper payload check failed.' }
$summary = [ordered]@{ ok=$true; packageFiles=$manifest.files.Count; powerShellFiles=$parseCount;
    geometryCases=$selfTest.geometryCases; placementCases=$selfTest.fixedPlacementCases; node=$runtime.Version;
    scope='Isolated package, compiler, listener identity, shortcut/appearance restore and video payload. No live Codex was restarted.' }
Write-DragonJson (Join-Path $root '.local\test-report.json') $summary
Write-Host ($summary | ConvertTo-Json)
