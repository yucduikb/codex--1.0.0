# Deployment and maintenance

This repository packages a Windows x64 Codex startup animation and video-wallpaper integration. Read README.md and docs/DEPLOYMENT.md before deployment.

## User-requested deployment

1. Work from the complete extracted/cloned repository. Do not synthesize missing media or copy another installation's profile/config.
2. Run Windows PowerShell 5.1: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1`. If using the complete offline ZIP, add `-Offline`.
3. The installer verifies package-manifest.json, validates the official Store package, builds the actual source using the Windows Framework compiler, and installs the wallpaper engine and signed pinned Node runtime.
4. Verify the installation marker, runtime hashes and actual Desktop/Start Menu .lnk targets. Sandbox views of WScript shortcut metadata can differ from the interactive user's view; do not report successful integration from a name alone.
5. Report the installed path, entrypoints and Uninstall.cmd. Do not close a running user session automatically; launch only when requested. Existing pinned taskbar/Start items may require repinning.

The installer does not require an API key. It does not deploy the Codex app itself. A public web chat without local execution tools cannot perform the deployment. `-Portable` prepares files without touching appearance or shortcuts and may be used for isolated validation.

## Boundaries

Keep strict official package/executable/CDP listener identity, loopback binding, signed runtime checks, decoding-frame readiness and backup/restore behavior. Do not patch WindowsApps or redirect debugging to external hosts. Do not silently replace another skin installation. Use installation-local skin state and profile. Preserve original MIT copyrights and third-party notices.

Code-license permissions do not establish redistribution rights for wallpaper, characters or audio. Check the media notices before publishing; replace media if rights cannot be confirmed. No automatic upload, GitHub publish or message sending is part of deployment.

## Editing and verification

Use scripts/Build.ps1, scripts/Test-Package.ps1 and scripts/Build-Release.ps1. After changing distributable source or media run scripts/Update-Manifest.ps1, then repeat tests. Never submit .local/, releases/, engine/runtime/, skin/, state/, logs/, .integration/, profiles or config backups. The offline release embeds Node, the Git source tree does not.

Do not advertise guaranteed zero waiting on arbitrary cold starts. The 13.65-second handoff occurs when the actual verified video wallpaper is ready; the moving continuation is a fallback and does not mean the app is already interactive. Document measured results and their scope honestly.
