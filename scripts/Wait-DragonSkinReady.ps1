[CmdletBinding()]
param([string]$ReadyFile, [ValidateRange(0,30000)][int]$ReadyDelayMilliseconds = 0)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (!$ReadyFile) { $ReadyFile = Join-Path $root 'state\skin-ready.flag' }
$skinRoot = Join-Path $root 'skin'
$skinScripts = Join-Path $root 'engine\scripts'
$injector = Join-Path $skinScripts 'injector.mjs'
$statePath = Join-Path $skinRoot 'state.json'
$themeDir = Join-Path $root 'themes\dragon'
$profilePath = Join-Path $skinRoot 'cdp-profile'
$log = Join-Path $root 'logs\skin-handoff.log'
$env:DREAMSKIN_COMPAT_PROFILE = '0'
$operationLock = $null
$clock = [Diagnostics.Stopwatch]::StartNew()

function Write-HandoffLog([string]$Message) {
  Add-Content -LiteralPath $log -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') +
    ' +' + $clock.ElapsedMilliseconds + 'ms ' + $Message)
}

function Test-QuickEndpoint([int]$Port) {
  try {
    $request = [Net.HttpWebRequest]::Create("http://127.0.0.1:$Port/json/version")
    $request.Proxy = $null
    $request.Timeout = 200
    $response = $request.GetResponse()
    try { return $response.StatusCode -eq [Net.HttpStatusCode]::OK }
    finally { $response.Dispose() }
  } catch { return $false }
}

function Select-StartupPort([int]$PreferredPort) {
  # Probe availability by binding loopback instead of loading the network
  # inventory provider before the desktop process can even begin startup.
  for ($candidate = $PreferredPort; $candidate -le [Math]::Min(65535, $PreferredPort + 100); $candidate++) {
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $candidate)
    try {
      $listener.Server.ExclusiveAddressUse = $true
      $listener.Start()
      return $candidate
    } catch [Net.Sockets.SocketException] {
      # Existing or unrelated listeners remain untouched.
    } finally { $listener.Stop() }
  }
  throw 'No available local startup port was found.'
}

function Get-StartupVerifiedIdentity([int]$Port, [object]$Codex) {
  if (![DragonCodexBoot.StartupIdentity]::IsOwnedLoopbackPort($Port, $Codex.Executable)) { return $null }
  $browser = Get-DreamSkinCdpBrowserIdentity -Port $Port
  if (!$browser) { return $null }
  $targets = Get-DreamSkinCdpTargets -Port $Port
  if ($targets.Count -eq 0) { return $null }
  if (![DragonCodexBoot.StartupIdentity]::IsOwnedLoopbackPort($Port, $Codex.Executable)) { return $null }
  return [pscustomobject]@{
    BrowserId = $browser.BrowserId
    BrowserWebSocketDebuggerUrl = $browser.WebSocketDebuggerUrl
    Browser = $browser.Browser
    TargetCount = $targets.Count
  }
}

function Test-ReusableSkinWatcher([object]$State, [object]$Identity, [object]$Node) {
  if (!$State -or !$State.injectorPid -or !$State.injectorStartedAt -or
    "$($State.browserId)" -cne "$($Identity.BrowserId)" -or [int]$State.port -ne $port -or
    !(Test-DreamSkinPathEqual $State.nodePath $Node.Path) -or
    !(Test-DreamSkinPathEqual $State.injectorPath $injector) -or
    !(Test-DreamSkinPathEqual $State.themeDir $themeDir)) { return $false }
  $processHandle = Get-Process -Id ([int]$State.injectorPid) -ErrorAction SilentlyContinue
  if (!$processHandle) { return $false }
  try {
    if ($processHandle.StartTime.ToUniversalTime().ToString('o') -cne "$($State.injectorStartedAt)") { return $false }
    $processInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $($State.injectorPid)" -ErrorAction Stop
    if (!$processInfo -or !(Test-DreamSkinPathEqual (Get-DreamSkinProcessExecutablePath $processInfo) $Node.Path)) { return $false }
    $commandLine = "$($processInfo.CommandLine)"
    foreach ($token in @($injector, '--watch', '--theme-dir', $themeDir, '--pause-file', (Join-Path $skinRoot 'paused'))) {
      if (!(Test-DreamSkinCommandLineToken -CommandLine $commandLine -Token $token)) { return $false }
    }
    return [regex]::IsMatch($commandLine, ('(?:^|\s)--port(?:=|\s+)' + $port + '(?=$|\s)')) -and
      [regex]::IsMatch($commandLine, ('(?:^|\s)--browser-id(?:=|\s+)' + [regex]::Escape($Identity.BrowserId) + '(?=$|\s)'))
  } catch { return $false }
  finally { $processHandle.Dispose() }
}

try {
  New-Item -ItemType Directory -Path (Split-Path -Parent $log),(Split-Path -Parent $ReadyFile) -Force | Out-Null
  Remove-Item -LiteralPath $ReadyFile -Force -ErrorAction SilentlyContinue
  Write-HandoffLog 'coordinator-started parallel-direct-launch'
  . (Join-Path $skinScripts 'common-windows.ps1')
  . (Join-Path $skinScripts 'theme-windows.ps1')
  [void][Reflection.Assembly]::LoadFrom((Join-Path $root 'DragonCodexBoot.exe'))
  $operationLock = Enter-DreamSkinOperationLock -TimeoutMilliseconds 5000
  $previousState = Read-DreamSkinState -Path $statePath
  $codex = Get-DreamSkinCodexInstall
  $port = if ($previousState -and $previousState.port) { [int]$previousState.port } else { 9335 }
  Assert-DreamSkinPort -Port $port
  Write-HandoffLog 'store-package-validated'

  $identity = $null
  if (Test-QuickEndpoint $port) {
    foreach ($registeredInstall in @(Get-DreamSkinRegisteredCodexInstalls)) {
      $identity = Get-StartupVerifiedIdentity -Port $port -Codex $registeredInstall
      if ($identity) { $codex = $registeredInstall; break }
    }
  }
  Set-DreamSkinPaused -Paused $false -StateRoot $skinRoot | Out-Null
  $arguments = @('--remote-debugging-address=127.0.0.1', "--remote-debugging-port=$port",
    "--user-data-dir=$profilePath", '--disable-backgrounding-occluded-windows',
    '--disable-renderer-backgrounding', '--disable-background-timer-throttling',
    '--disable-features=CalculateNativeWinOcclusion')
  if (!$identity) {
    $existing = @(Get-DreamSkinCodexProcesses -Codex $codex)
    if ($existing.Count -gt 0) {
      Write-HandoffLog 'closing-existing-unskinned-session'
      Stop-DreamSkinCodex -Codex $codex
    }
    $port = Select-StartupPort -PreferredPort $port
    $arguments[1] = "--remote-debugging-port=$port"
    # Start the exact validated Store executable once with skin parameters.
    $appProcessId = Start-DreamSkinCodexDirect -Codex $codex -Arguments $arguments
    Write-HandoffLog ("direct-codex-started pid=$appProcessId port=$port")
  } else {
    # Closing the last window leaves this application's process and CDP endpoint
    # alive. A live endpoint alone does not reopen it. Forward a second-instance
    # activation to the same verified package/profile so its existing window is
    # restored without destroying the renderer, wallpaper or conversation.
    $activationId = Start-DreamSkinCodexDirect -Codex $codex -Arguments $arguments
    Write-HandoffLog ("existing-session-window-activation pid=$activationId")
  }
  # Keep the complete signed-runtime checks, but overlap them with Codex's
  # startup instead of making the desktop process wait for the skin runtime.
  $node = Get-DreamSkinNodeRuntime
  Write-HandoffLog 'signed-node-runtime-validated'
  if (!$identity) {
    $deadline = (Get-Date).AddSeconds(45)
    while (!$identity -and (Get-Date) -lt $deadline) {
      if (Test-QuickEndpoint $port) {
        $identity = Get-StartupVerifiedIdentity -Port $port -Codex $codex
      }
      if (!$identity) { Start-Sleep -Milliseconds 100 }
    }
    if (!$identity) { throw 'The validated Codex process did not expose a verified local renderer.' }
  }
  Write-HandoffLog 'cdp-owner-and-browser-verified'
  if (Test-ReusableSkinWatcher -State $previousState -Identity $identity -Node $node) {
    $watcherId = [int]$previousState.injectorPid
    $startedAt = "$($previousState.injectorStartedAt)"
    Write-HandoffLog ("skin-watcher-reused pid=$watcherId")
  } else {
    if (!(Stop-DreamSkinRecordedInjector -State $previousState)) {
      throw 'The previous skin watcher could not be reconciled.'
    }
    $watchArgs = @($injector, '--watch', '--port', "$port", '--browser-id', $identity.BrowserId,
      '--theme-dir', $themeDir, '--pause-file', (Join-Path $skinRoot 'paused'))
    $watchLine = ConvertTo-DreamSkinArgumentLine -Arguments $watchArgs
    $daemon = Start-Process -FilePath $node.Path -ArgumentList $watchLine -WindowStyle Hidden -PassThru `
      -RedirectStandardOutput (Join-Path $root 'logs\skin-watcher.log') `
      -RedirectStandardError (Join-Path $root 'logs\skin-watcher-error.log')
    $watcherId = $daemon.Id
    $startedAt = Get-DreamSkinProcessStartedAt -ProcessId $watcherId
    if (!$startedAt) { throw 'The skin watcher exited before its process identity could be saved.' }
    Write-HandoffLog ("skin-watcher-started pid=$watcherId")
  }
  $state = [pscustomobject]@{
    schemaVersion = 3; platform = 'windows'; port = $port
    injectorPid = $watcherId; injectorStartedAt = $startedAt; injectorPath = $injector
    nodePath = $node.Path; nodeVersion = $node.Version
    codexExe = $codex.Executable; codexPackageRoot = $codex.PackageRoot
    codexPackageFullName = $codex.PackageFullName; codexPackageFamilyName = $codex.PackageFamilyName
    codexVersion = $codex.Version; browserId = $identity.BrowserId
    profilePath = $profilePath; themeDir = $themeDir; pauseFile = (Join-Path $skinRoot 'paused')
    createdAt = (Get-Date).ToUniversalTime().ToString('o')
  }
  Write-DreamSkinState -Path $statePath -State $state
  Exit-DreamSkinOperationLock -Mutex $operationLock
  $operationLock = $null
  & $node.Path (Join-Path $PSScriptRoot 'Wait-DragonSkinReady.mjs') `
    --injector $injector --theme-dir $themeDir --port "$port" `
    --browser-id $identity.BrowserId --ready-file $ReadyFile `
    --not-before-ms "$ReadyDelayMilliseconds" `
    --report (Join-Path $root 'qa\last-skin-ready.json')
  if ($LASTEXITCODE -ne 0) { throw 'The animated wallpaper readiness check failed.' }
  Write-HandoffLog 'skin-ready decoded-video-playing'
} catch {
  Write-HandoffLog ('coordinator-error=' + $_.Exception.Message)
  exit 1
} finally {
  if ($operationLock) { Exit-DreamSkinOperationLock -Mutex $operationLock }
}
