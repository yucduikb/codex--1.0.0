import fs from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import assert from 'node:assert/strict';

const options = Object.fromEntries(Array.from({length: (process.argv.length - 2) / 2},
  (_, index) => process.argv.slice(2 + index * 2, 4 + index * 2)));
const port = Number(options['--port']);
const browserId = options['--browser-id'];
const readyFile = options['--ready-file'];
const notBeforeMs = Number(options['--not-before-ms'] ?? 0);
const timeoutMs = Number(options['--timeout-ms'] ?? 70000);
assert(Number.isInteger(notBeforeMs) && notBeforeMs >= 0 && notBeforeMs <= 30000);
assert(Number.isInteger(timeoutMs) && timeoutMs >= 1000 && timeoutMs <= 70000);
assert(Number.isInteger(port) && port >= 1024 && port <= 65535);
assert(/^[A-Za-z0-9_-]+$/.test(browserId));
const {loadPayload, verifySession} = await import(pathToFileURL(options['--injector']).href);
const payload = await loadPayload(options['--theme-dir']);
assert.equal(payload.mediaType, 'video', 'An animated video theme is required');
const started = Date.now();
const milestones = {};
const sessions = new Map();
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));

function validatedSocket(url, path) {
  const parsed = new URL(url);
  assert.equal(parsed.protocol, 'ws:');
  assert.equal(parsed.hostname, '127.0.0.1');
  assert.equal(Number(parsed.port), port);
  assert.equal(parsed.pathname, path);
  assert(!parsed.username && !parsed.password && !parsed.search && !parsed.hash);
  return parsed.href;
}

class Session {
  constructor(url) {
    this.socket = new WebSocket(url);
    this.pending = new Map();
    this.sequence = 0;
    this.closed = false;
    this.socket.addEventListener('message', event => {
      const message = JSON.parse(event.data);
      const item = this.pending.get(message.id);
      if (!item) return;
      clearTimeout(item.timer);
      this.pending.delete(message.id);
      if (message.error) {
        const error = new Error(message.error.message);
        error.cdpCode = message.error.code;
        item.reject(error);
      } else item.resolve(message.result);
    });
    this.socket.addEventListener('close', () => this.close());
    this.socket.addEventListener('error', () => this.close());
  }
  async open() {
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => { this.close(); reject(new Error('Socket open timed out')); }, 2000);
      this.socket.addEventListener('open', () => { clearTimeout(timer); resolve(); }, {once:true});
      this.socket.addEventListener('error', () => { clearTimeout(timer); reject(new Error('Socket failed')); }, {once:true});
    });
    return this;
  }
  send(method, params = {}) {
    if (this.closed) return Promise.reject(new Error('Session closed'));
    return new Promise((resolve, reject) => {
      const id = ++this.sequence;
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`${method} timed out`));
      }, 2000);
      this.pending.set(id, {resolve, reject, timer});
      this.socket.send(JSON.stringify({id, method, params}));
    });
  }
  async evaluate(expression) {
    const result = await this.send('Runtime.evaluate', {expression, awaitPromise:true, returnByValue:true});
    if (result.exceptionDetails) throw new Error('Renderer not ready for verification');
    return result.result?.value;
  }
  close() {
    if (this.closed) return;
    this.closed = true;
    for (const item of this.pending.values()) {
      clearTimeout(item.timer);
      item.reject(new Error('Session closed'));
    }
    this.pending.clear();
    this.socket.close();
  }
}

async function json(endpoint) {
  const response = await fetch(`http://127.0.0.1:${port}/json/${endpoint}`, {
    signal: AbortSignal.timeout(1500), redirect:'error'
  });
  assert(response.ok);
  return response.json();
}

let anchor;
let lastCheck = null;
let passed = false;
try {
  const version = await json('version');
  anchor = await new Session(validatedSocket(version.webSocketDebuggerUrl,
    `/devtools/browser/${browserId}`)).open();
  while (Date.now() - started < timeoutMs) {
    if (anchor.closed) throw new Error('The verified Codex browser closed during startup');
    const targets = await json('list');
    for (const target of targets) {
      if (target.type !== 'page' || target.url !== 'app://-/index.html' ||
          !/^[A-Za-z0-9_-]+$/.test(target.id)) continue;
      let session = sessions.get(target.id);
      try {
        if (!session || session.closed) {
          session = await new Session(validatedSocket(target.webSocketDebuggerUrl,
            `/devtools/page/${target.id}`)).open();
          sessions.set(target.id, session);
          milestones.rendererConnectedMs ??= Date.now() - started;
        }
        const check = await verifySession(session, target.id, payload.theme.id, payload.revision);
        if (check.installed) milestones.themeInstalledMs ??= Date.now() - started;
        if (check.mediaReady) milestones.mediaAttachedMs ??= Date.now() - started;
        if (check.pass) milestones.structureReadyMs ??= Date.now() - started;
        lastCheck = {pass:check.pass, readiness:check.readiness, themeId:check.themeId,
          mediaType:check.mediaType, transport:check.transport, viewport:check.viewport};
        if (!check.pass || check.transport === 'poster') continue;
        const video = await session.evaluate(`(async () => {
          const video = document.getElementById('codex-dream-skin-media');
          if (!(video instanceof HTMLVideoElement)) return {playing:false};
          const first = video.currentTime;
          const framesBefore = video.getVideoPlaybackQuality?.().totalVideoFrames ?? 0;
          await new Promise(resolve => setTimeout(resolve, 180));
          const framesAfter = video.getVideoPlaybackQuality?.().totalVideoFrames ?? 0;
          const advanced = video.currentTime !== first && framesAfter > framesBefore;
          return {playing:!video.paused && !video.ended && video.readyState >= 2 && advanced,
            readyState:video.readyState, currentTime:video.currentTime, framesBefore, framesAfter,
            width:video.videoWidth, height:video.videoHeight};
        })()`);
        lastCheck.video = video;
        if (!video.playing) continue;
        if (Date.now() - started < notBeforeMs) continue;
        milestones.videoPlayingMs = Date.now() - started;
        if (anchor.closed) throw new Error('Verified browser closed before handoff');
        const report = {...lastCheck, browserId, targetId:target.id, mediaBytes:payload.mediaSize,
          milestones, verificationMs:Date.now()-started,
          verifiedAt:new Date().toISOString()};
        await fs.writeFile(options['--report'], JSON.stringify(report, null, 2));
        await fs.writeFile(readyFile, JSON.stringify({browserId, targetId:target.id, readyAt:report.verifiedAt}));
        console.log(JSON.stringify(report));
        passed = true;
        break;
      } catch (error) {
        lastCheck = {error:error.message};
        session?.close();
        sessions.delete(target.id);
      }
    }
    if (passed) break;
    await pause(100);
  }
  if (!passed) {
    await fs.writeFile(options['--report'], JSON.stringify({pass:false, lastCheck, milestones,
      verificationMs:Date.now()-started, verifiedAt:new Date().toISOString()}, null, 2));
    throw new Error(`Animated wallpaper not ready: ${JSON.stringify(lastCheck)}`);
  }
} finally {
  for (const session of sessions.values()) session.close();
  anchor?.close();
}
