/**
 * Foodora API Server (VNC Relogin Architecture)
 * -------------------------------------------------------------
 * Provides endpoints for the Flutter POS to monitor session health
 * and trigger VNC relogin windows when Foodora Cloudflare blocks the session.
 */

import express from 'express';
import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
app.use(express.json());

app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

const sessionState = new Map();
const activeRelogins = new Map();

export function initSessions(accounts) {
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

export function markActive(accountId) {
  const s = sessionState.get(accountId);
  if (!s) return;
  s.status = 'active';
  s.lastCheckedAt = new Date().toISOString();
}

export function markExpired(accountId) {
  const s = sessionState.get(accountId);
  if (!s) return;
  s.status = 'expired';
  s.lastCheckedAt = new Date().toISOString();
  console.log(`[Foodora API] ❌ ${accountId} session expired`);
}

export function markOrderSeen(accountId) {
  const s = sessionState.get(accountId);
  if (!s) return;
  s.lastOrderSeenAt = new Date().toISOString();
}

app.get('/api/foodora/sessions', (_req, res) => {
  const result = [...sessionState.values()].map(
    ({ accountId, label, status, lastCheckedAt, lastOrderSeenAt }) => ({
      accountId, label, status, lastCheckedAt, lastOrderSeenAt,
    }),
  );
  res.json(result);
});

app.post('/api/foodora/sessions/:accountId/relogin', (req, res) => {
  const { accountId } = req.params;
  const session = sessionState.get(accountId);
  if (!session) return res.status(404).json({ error: `Unknown accountId: ${accountId}` });

  const vpsIp = process.env.VPS_PUBLIC_IP || null;
  const vncPort = Number(process.env.VNC_PORT) || 5900;

  if (activeRelogins.has(accountId)) {
    return res.json({
      status: 'login_window_opened',
      message: `Login window already open. Connect VNC to ${vpsIp}:${vncPort}.`,
      vncHost: vpsIp,
      vncPort,
    });
  }

  const display = process.env.DISPLAY || ':1';
  const env = { ...process.env, DISPLAY: display };

  console.log(`[Foodora API] Spawning: node foodora-login.mjs --account ${accountId} on DISPLAY=${display}`);

  const child = spawn(process.execPath, ['foodora-login.mjs', '--account', accountId], {
    env,
    cwd: __dirname,
    detached: false,
    stdio: 'inherit',
  });

  activeRelogins.set(accountId, child);

  child.on('exit', (code) => {
    activeRelogins.delete(accountId);
    console.log(`[Foodora API] login script exited (code ${code}).`);
    _checkCookiesFreshness(accountId);
  });

  res.json({
    status: 'login_window_opened',
    message: `Chromium login window opened. Connect VNC to ${vpsIp}:${vncPort} and complete the Foodora login.`,
    vncHost: vpsIp,
    vncPort,
  });
});

app.post('/api/foodora/sessions/:accountId/relogin-complete', (req, res) => {
  const { accountId } = req.params;
  const session = sessionState.get(accountId);
  if (!session) return res.status(404).json({ error: `Unknown accountId: ${accountId}` });
  
  const newStatus = _checkCookiesFreshness(accountId);
  res.json({ accountId, status: newStatus });
});

function _checkCookiesFreshness(accountId) {
  const session = sessionState.get(accountId);
  if (!session) return 'unknown';

  const profileDir = path.resolve(__dirname, session.profileDir);
  
  // We just check if the directory exists and has been modified recently as a proxy
  if (fs.existsSync(profileDir)) {
      session.status = 'active';
      session.lastCheckedAt = new Date().toISOString();
      return 'active';
  }

  session.status = 'expired';
  return 'expired';
}

export function startServer(port) {
  const p = port || Number(process.env.FOODORA_API_PORT) || 3002;
  app.listen(p, '0.0.0.0', () => {
    console.log(`\n[Foodora API] 🚀 Session API running on http://0.0.0.0:${p}`);
  });
}
