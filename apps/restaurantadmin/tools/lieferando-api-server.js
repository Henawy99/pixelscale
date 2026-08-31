/**
 * api-server.js
 *
 * A lightweight Express HTTP server that runs ALONGSIDE monitor.js (imported
 * by it via require). Exposes session-health endpoints consumed by the Flutter
 * POS "Platforms" screen.
 *
 * Endpoints:
 *   GET  /api/sessions                              – list all account statuses
 *   POST /api/sessions/:accountId/relogin           – open a headed login window
 *   POST /api/sessions/:accountId/relogin-complete  – verify & confirm login done
 *
 * On Linux VPS with Xvfb + x11vnc running on DISPLAY=:1, the headed browser
 * spawned by the relogin endpoint is visible over VNC.
 *
 * ─── DEPLOY INSTRUCTIONS (copy this file alongside monitor.js) ────────────
 * 1. Install express:  npm install express
 * 2. Copy this file to your lieferando-multi-account directory
 * 3. Set environment variables in .env (see below)
 * 4. monitor.js already requires() this file — just run: node monitor.js
 *
 * Required .env additions:
 *   VPS_PUBLIC_IP=123.45.67.89       # Your VPS public IP shown in VNC instructions
 *   VNC_PORT=5901                    # Default x11vnc port
 *   API_PORT=3001                    # Port for this API server
 *   WEBHOOK_URL=https://iluhlynzkgubtaswvgwt.supabase.co/functions/v1/receive-lieferando-order
 *   WEBHOOK_AUTH_TOKEN=              # Optional: add as x-webhook-token header if you add auth to the edge function
 *
 * VNC setup (Ubuntu VPS):
 *   sudo apt-get install -y xvfb x11vnc
 *   # Start Xvfb virtual display
 *   Xvfb :1 -screen 0 1280x800x24 &
 *   # Start VNC server (no password - change -nopw to -passwd /path/to/pwdfile for password)
 *   x11vnc -display :1 -nopw -listen 0.0.0.0 -xkb -forever &
 *   # Start monitor with DISPLAY set
 *   DISPLAY=:1 node monitor.js
 * ──────────────────────────────────────────────────────────────────────────
 */

'use strict';

const express = require('express');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(express.json());

// ── CORS (allow requests from the Flutter app on any IP) ────────────────────
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

// ── In-memory session state (updated by monitor.js hooks) ─────────────────
// Shape: Map<accountId, SessionState>
const sessionState = new Map();

/**
 * Initialise state for every account when the monitor boots.
 * Call this from monitor.js before starting accounts.
 * @param {Array<{id:string, label:string, profileDir:string}>} accounts
 */
function initSessions(accounts) {
  for (const a of accounts) {
    if (!sessionState.has(a.id)) {
      sessionState.set(a.id, {
        accountId: a.id,
        label: a.label,
        profileDir: a.profileDir,
        status: 'unknown',
        lastCheckedAt: null,
        lastOrderSeenAt: null,
      });
    }
  }
}

/** Call from monitor.js on each successful poll. */
function markActive(accountId) {
  const s = sessionState.get(accountId);
  if (!s) return;
  s.status = 'active';
  s.lastCheckedAt = new Date().toISOString();
}

/** Call from monitor.js when a session-expired redirect is detected. */
function markExpired(accountId) {
  const s = sessionState.get(accountId);
  if (!s) return;
  s.status = 'expired';
  s.lastCheckedAt = new Date().toISOString();
  console.log(`[api-server] ❌ ${accountId} session expired`);
}

/** Call from monitor.js when a new order is seen. */
function markOrderSeen(accountId) {
  const s = sessionState.get(accountId);
  if (!s) return;
  s.lastOrderSeenAt = new Date().toISOString();
}

// ── GET /api/sessions ────────────────────────────────────────────────────────
app.get('/api/sessions', (_req, res) => {
  const result = [...sessionState.values()].map(
    ({ accountId, label, status, lastCheckedAt, lastOrderSeenAt }) => ({
      accountId, label, status, lastCheckedAt, lastOrderSeenAt,
    }),
  );
  res.json(result);
});

// ── Active relogin child processes ───────────────────────────────────────────
const activeRelogins = new Map();

// ── POST /api/sessions/:accountId/relogin ────────────────────────────────────
app.post('/api/sessions/:accountId/relogin', (req, res) => {
  const { accountId } = req.params;
  const session = sessionState.get(accountId);
  if (!session) return res.status(404).json({ error: `Unknown accountId: ${accountId}` });

  const vpsIp = process.env.VPS_PUBLIC_IP || null;
  const vncPort = Number(process.env.VNC_PORT) || 5900;

  if (activeRelogins.has(accountId)) {
    return res.json({
      status: 'login_window_opened',
      message: `Login window already open. Connect VNC to ${vpsIp}:${vncPort} and complete the login.`,
      vncHost: vpsIp,
      vncPort,
    });
  }

  // Spawn login.js using the virtual Xvfb display
  const display = process.env.DISPLAY || ':1';
  const env = { ...process.env, DISPLAY: display };

  console.log(`[api-server] Spawning: node login.js --account ${accountId} on DISPLAY=${display}`);

  const child = spawn(process.execPath, ['login.js', '--account', accountId], {
    env,
    cwd: __dirname, // login.js is in the same directory as api-server.js
    detached: false,
    stdio: 'inherit',
  });

  activeRelogins.set(accountId, child);

  child.on('exit', (code) => {
    activeRelogins.delete(accountId);
    console.log(`[api-server] login.js for ${accountId} exited (code ${code}). Re-checking cookies...`);
    _checkCookiesFreshness(accountId);
  });

  child.on('error', (err) => {
    activeRelogins.delete(accountId);
    console.error(`[api-server] login.js spawn error for ${accountId}:`, err.message);
  });

  const vncMsg = vpsIp
    ? `Chromium login window opened. Connect your VNC client to ${vpsIp}:${vncPort} and complete the Lieferando login. When done, tap "Done" in the POS app.`
    : `Chromium login window opened on the server. Connect via VNC and complete the login. When done, tap "Done" in the POS app.`;

  res.json({
    status: 'login_window_opened',
    message: vncMsg,
    vncHost: vpsIp,
    vncPort,
  });
});

// ── POST /api/sessions/:accountId/relogin-complete ──────────────────────────
app.post('/api/sessions/:accountId/relogin-complete', (req, res) => {
  const { accountId } = req.params;
  const session = sessionState.get(accountId);
  if (!session) return res.status(404).json({ error: `Unknown accountId: ${accountId}` });
  const newStatus = _checkCookiesFreshness(accountId);
  res.json({ accountId, status: newStatus });
});

// ── Healthcheck ──────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => res.json({ ok: true, uptime: process.uptime() }));

// ── Internal helpers ─────────────────────────────────────────────────────────
function _checkCookiesFreshness(accountId) {
  const session = sessionState.get(accountId);
  if (!session) return 'unknown';

  const profileDir = path.resolve(__dirname, '..', session.profileDir);

  // Playwright / Chromium stores cookies in these locations
  const cookiePaths = [
    path.join(profileDir, 'Default', 'Cookies'),
    path.join(profileDir, 'Default', 'Network', 'Cookies'),
    path.join(profileDir, 'Cookies'),
  ];

  for (const p of cookiePaths) {
    if (fs.existsSync(p)) {
      const ageMs = Date.now() - fs.statSync(p).mtimeMs;
      if (ageMs < 5 * 60 * 1000) { // 5-minute freshness window
        session.status = 'active';
        session.lastCheckedAt = new Date().toISOString();
        console.log(`[api-server] ${accountId} → active (cookies ${Math.round(ageMs / 1000)}s old)`);
        return 'active';
      }
      break;
    }
  }

  session.status = 'expired';
  session.lastCheckedAt = new Date().toISOString();
  console.log(`[api-server] ${accountId} → still expired`);
  return 'expired';
}

// ── Start server ─────────────────────────────────────────────────────────────
function startServer(port) {
  const p = port || Number(process.env.API_PORT) || 3001;
  app.listen(p, '0.0.0.0', () => {
    console.log(`\n[api-server] 🚀 Session API running on http://0.0.0.0:${p}`);
    console.log(`[api-server]   GET  /api/sessions`);
    console.log(`[api-server]   POST /api/sessions/:id/relogin`);
    console.log(`[api-server]   POST /api/sessions/:id/relogin-complete\n`);
  });
}

module.exports = { initSessions, markActive, markExpired, markOrderSeen, startServer };
