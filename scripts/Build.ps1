[CmdletBinding()]
param([string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!$OutputDirectory) { $OutputDirectory = Join-Path $repoRoot '.local\build' }
$output = [IO.Path]::GetFullPath($OutputDirectory)
$compilerRoot = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$compiler = Join-Path $compilerRoot 'csc.exe'
if (!(Test-Path -LiteralPath $compiler)) { throw 'Windows x64 with .NET Framework 4.8 is required.' }
New-Item -ItemType Directory -Path $output -Force | Out-Null
$references = @('System.dll','System.Core.dll','System.Xaml.dll','System.Web.Extensions.dll','System.Drawing.dll','System.Windows.Forms.dll')
foreach ($name in @('WindowsBase.dll','PresentationCore.dll','PresentationFramework.dll')) {
    $references += Join-Path $compilerRoot ('WPF\' + $name)
}
$compilerArgs = @('/nologo','/target:winexe','/platform:x64','/optimize+',
    ('/win32manifest:' + (Join-Path $repoRoot 'src\app.manifest')),('/out:' + (Join-Path $output 'DragonCodexBoot.exe')))
foreach ($reference in $references) { $compilerArgs += '/reference:' + $reference }
$compilerArgs += Join-Path $repoRoot 'src\DragonCodexBoot.cs'
& $compiler @compilerArgs
if ($LASTEXITCODE -ne 0) { throw 'Launcher compilation failed.' }
Copy-Item -LiteralPath (Join-Path $repoRoot 'config\launcher.json') -Destination (Join-Path $output 'launcher.json') -Force
Write-Output (Join-Path $output 'DragonCodexBoot.exe')
