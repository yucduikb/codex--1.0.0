param([string]$AppRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) '.local\build'))
$ErrorActionPreference = 'Stop'
$root = $AppRoot
[void][Reflection.Assembly]::LoadFrom((Join-Path $root 'DragonCodexBoot.exe'))
$ownExecutable = (Get-Process -Id $PID).Path
$passed = 0
foreach ($address in @([Net.IPAddress]::Loopback, [Net.IPAddress]::IPv6Loopback, [Net.IPAddress]::Any, [Net.IPAddress]::IPv6Any)) {
  $listener = [Net.Sockets.TcpListener]::new($address, 0)
  try {
    if ($address.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetworkV6) { $listener.Server.DualMode = $false }
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    $expected = [Net.IPAddress]::IsLoopback($address)
    $actual = [DragonCodexBoot.StartupIdentity]::IsOwnedLoopbackPort($port, $ownExecutable)
    if ($actual -ne $expected) { throw "Unexpected listener validation for $address" }
    if ([DragonCodexBoot.StartupIdentity]::IsOwnedLoopbackPort($port, 'C:\Windows\System32\notepad.exe')) {
      throw "Wrong executable was accepted for $address"
    }
    $passed += 2
  } finally { $listener.Stop() }
}
if ([DragonCodexBoot.StartupIdentity]::IsOwnedLoopbackPort(1023, $ownExecutable)) { throw 'Privileged port accepted' }
$passed++
Write-Output "PASS: $passed native ownership cases, both address families, wildcard rejection and exact executable identity."
