import AsyncStorage from '@react-native-async-storage/async-storage';
import { BookingsResponse, AnalyzeResponse, AnalyzeRequest, ZohoConfig } from '../types';

export const DEFAULT_API_URL = 'https://review-app-seven-kappa.vercel.app';
const STORAGE_KEY_API_URL = '@pixelreview_api_url';
const STORAGE_KEY_ZOHO_CONFIG = '@pixelreview_zoho_config';
const STORAGE_KEY_GEMINI_KEY = '@pixelreview_gemini_key';

export async function getApiBaseUrl(): Promise<string> {
  try {
    const saved = await AsyncStorage.getItem(STORAGE_KEY_API_URL);
    if (saved && saved.trim()) return saved.trim();
  } catch {
    // fallback
  }
  return DEFAULT_API_URL;
}

export async function setApiBaseUrl(url: string): Promise<void> {
  await AsyncStorage.setItem(STORAGE_KEY_API_URL, url.trim());
}

export async function getZohoConfig(): Promise<ZohoConfig | null> {
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY_ZOHO_CONFIG);
    if (raw) return JSON.parse(raw);
  } catch {
    // ignore
  }
  return null;
}

export async function saveZohoConfig(cfg: ZohoConfig): Promise<void> {
  await AsyncStorage.setItem(STORAGE_KEY_ZOHO_CONFIG, JSON.stringify(cfg));
}

export async function getGeminiKey(): Promise<string> {
  try {
    return (await AsyncStorage.getItem(STORAGE_KEY_GEMINI_KEY)) || '';
  } catch {
    return '';
  }
}

export async function saveGeminiKey(key: string): Promise<void> {
  await AsyncStorage.setItem(STORAGE_KEY_GEMINI_KEY, key.trim());
}

export async function fetchLiveBookings(forceRefresh = false): Promise<BookingsResponse> {
  const baseUrl = await getApiBaseUrl();
  const zoho = await getZohoConfig();

  const headers: Record<string, string> = {
    'Accept': 'application/json',
  };

  if (zoho?.email) {
    headers['x-zoho-email'] = zoho.email;
    if (zoho.password) headers['x-zoho-password'] = zoho.password;
    if (zoho.host) headers['x-zoho-host'] = zoho.host;
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
      'Accept': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  const data: AnalyzeResponse = await res.json();
  return data;
}
