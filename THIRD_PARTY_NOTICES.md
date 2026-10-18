# Third-party notices

This is a Windows community integration based on Dragon Codex Boot and Codex Dynamic Skin. It is not an official OpenAI product.

## Launcher

Upstream: https://github.com/yushua0808-cpu/dragon-codex-boot

Base release: 0.2.0. Upstream main observed during export: `c63a203e5857e85fb3c8a9891eddb570e7a27b54`.
The exported source is the locally repaired installation, not an assertion that its bytes match that upstream commit.
MIT; retain the root `LICENSE`. Changes: parallel startup coordination, strict process/loopback identity,
decoded-video readiness, DWM/input handoff at the transition end, fixed centered placement, continuation video and deployment packaging.

## Dynamic wallpaper engine

Upstream: https://github.com/CCDawn/Codex-Dynamic-Skin

Version 1.7.3; upstream tag commit `5a0e74043b63ed9518ab37cdcf6865340a57006c`.
MIT; retain `licenses/Codex-Dynamic-Skin-LICENSE.txt`.
The `engine/` directory vendors the source modules needed for this startup and video-wallpaper workflow.
Local changes include longer initial shell readiness observation, excluded-window handling, timing logs,
and installation-local Windows theme preference storage. See `docs/CHANGES.md`.
The upstream standalone theme-manager application, tray, community marketplace and preset collection are not part of this integration.

## Node.js

Official runtime: https://nodejs.org/dist/v22.23.1/win-x64/node.exe

Source installer downloads https://nodejs.org/dist/v22.23.1/node-v22.23.1-win-x64.zip
with SHA-256 `7df0bc9375723f4a86b3aa1b7cc73342423d9677a8df4538aca31a049e309c29`, then extracts only the exact expected node.exe entry.

Pinned SHA-256: `f8d162c0641dcee512132f3bcf8a68169c7ecb852efd8e1a46c9fec5a0f469ed`.
Verified against https://nodejs.org/dist/v22.23.1/SHASUMS256.txt on 2026-10-18.
The full offline release includes this signed official binary. Source installation downloads it from nodejs.org.
Node.js and its bundled third-party components have their own notices; retain `licenses/Node.js-LICENSE.txt` and the runtime `LICENSE`.

## Media

The MIT source-code licenses do not grant rights to characters, video, music, artwork, product logos or trademarks.
Retain `media/MEDIA_NOTICE.md` and `themes/dragon/MEDIA_NOTICE.md`.
Startup video is retained from the upstream example; continuation video is derived from it.
The current wallpaper is exported from the local working setup. No independent blanket redistribution or commercial license for its artwork has been established in this export.
Maintainers must confirm media permissions before public distribution; otherwise replace the media with assets they own or are licensed to redistribute.

Codex, OpenAI, Microsoft and Windows names belong to their respective owners. This package includes no Codex application binary, extracted Codex icon, account credentials or conversation data.
