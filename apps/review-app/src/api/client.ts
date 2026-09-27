import { kv } from '../lib/storage';
import {
  BookingsResponse,
  AnalyzeResponse,
  AnalyzeRequest,
  ZohoConfig,
  GmailConfig,
} from '../types';

export const DEFAULT_API_URL = 'https://review-app-seven-kappa.vercel.app';
const STORAGE_KEY_API_URL = '@pixelreview_api_url';
const STORAGE_KEY_ZOHO_CONFIG = '@pixelreview_zoho_config';
const STORAGE_KEY_GMAIL_CONFIG = '@pixelreview_gmail_config';
const STORAGE_KEY_GEMINI_KEY = '@pixelreview_gemini_key';

export async function getApiBaseUrl(): Promise<string> {
  try {
    const saved = await kv.getItem(STORAGE_KEY_API_URL);
    if (saved && saved.trim()) return saved.trim();
  } catch {
    // fallback
  }
  return DEFAULT_API_URL;
}

export async function setApiBaseUrl(url: string): Promise<void> {
  await kv.setItem(STORAGE_KEY_API_URL, url.trim());
}

export async function getZohoConfig(): Promise<ZohoConfig | null> {
  try {
    const raw = await kv.getItem(STORAGE_KEY_ZOHO_CONFIG);
    if (raw) return JSON.parse(raw);
  } catch {
    // ignore
  }
  return null;
}

export async function saveZohoConfig(cfg: ZohoConfig): Promise<void> {
  await kv.setItem(STORAGE_KEY_ZOHO_CONFIG, JSON.stringify(cfg));
}

export async function getGmailConfig(): Promise<GmailConfig | null> {
  try {
    const raw = await kv.getItem(STORAGE_KEY_GMAIL_CONFIG);
    if (raw) return JSON.parse(raw);
  } catch {
    // ignore
  }
  return null;
}

export async function saveGmailConfig(cfg: GmailConfig): Promise<void> {
  await kv.setItem(STORAGE_KEY_GMAIL_CONFIG, JSON.stringify(cfg));
}

export async function getGeminiKey(): Promise<string> {
  try {
    return (await kv.getItem(STORAGE_KEY_GEMINI_KEY)) || '';
  } catch {
    return '';
  }
}

export async function saveGeminiKey(key: string): Promise<void> {
  await kv.setItem(STORAGE_KEY_GEMINI_KEY, key.trim());
}

export async function fetchLiveBookings(forceRefresh = false): Promise<BookingsResponse> {
  const baseUrl = await getApiBaseUrl();
  const [zoho, gmail] = await Promise.all([getZohoConfig(), getGmailConfig()]);

  const headers: Record<string, string> = {
    Accept: 'application/json',
  };

  if (zoho?.email) {
    headers['x-zoho-email'] = zoho.email;
    if (zoho.password) headers['x-zoho-password'] = zoho.password;
    if (zoho.host) headers['x-zoho-host'] = zoho.host;
    if (zoho.port) headers['x-zoho-port'] = String(zoho.port);
  }

  if (gmail?.email) {
    headers['x-gmail-email'] = gmail.email;
    if (gmail.password) headers['x-gmail-password'] = gmail.password;
    if (gmail.host) headers['x-gmail-host'] = gmail.host;
    if (gmail.port) headers['x-gmail-port'] = String(gmail.port);
  }

  const query = forceRefresh ? '?refresh=true' : '';
  const endpoint = `${baseUrl}/api/bookings${query}`;

  const res = await fetch(endpoint, {
    method: 'GET',
    headers,
  });

  if (!res.ok) {
    throw new Error(`Server returned HTTP ${res.status}`);
  }

  const data: BookingsResponse = await res.json();
  return data;
}

export async function testImapConnection(params: {
  provider: 'gmail' | 'zoho';
  email: string;
  password?: string;
  host?: string;
  port?: number;
}): Promise<{ success: boolean; message: string }> {
  const baseUrl = await getApiBaseUrl();
  const endpoint = `${baseUrl}/api/bookings/test`;

  const res = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify(params),
  });

  const data = await res.json();
  return {
    success: data.success || res.ok,
    message: data.message || (res.ok ? 'Connection successful!' : 'Connection failed'),
  };
}

export async function analyzeTourRequest(req: AnalyzeRequest): Promise<AnalyzeResponse> {
  const baseUrl = await getApiBaseUrl();
  const customKey = await getGeminiKey();

  const payload: AnalyzeRequest = {
    ...req,
    apiKey: req.apiKey || customKey || undefined,
  };

  const endpoint = `${baseUrl}/api/analyze`;
  const res = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify(payload),
  });

  const data: AnalyzeResponse = await res.json();
  return data;
}
