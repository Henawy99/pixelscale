'use client';

import React, { useState } from 'react';
import {
  X,
  ExternalLink,
  Check,
  Eye,
  EyeOff,
  Sparkles,
  Shield,
  Info,
  Mail,
  Server,
  RefreshCw,
  AlertCircle,
  CheckCircle2,
} from 'lucide-react';
import { ZohoConfig } from '@/lib/types';

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
  geminiKey: string;
  onSaveGeminiKey: (key: string) => void;
  zohoConfig: ZohoConfig;
  onSaveZohoConfig: (config: ZohoConfig) => void;
  onTestZohoConnection?: () => void;
}

export function SettingsModal({
  isOpen,
  onClose,
  geminiKey,
  onSaveGeminiKey,
  zohoConfig,
  onSaveZohoConfig,
}: SettingsModalProps) {
  const [activeTab, setActiveTab] = useState<'zoho' | 'gemini'>('zoho');

  // Gemini state
  const [apiKey, setApiKey] = useState(geminiKey);
  const [showKey, setShowKey] = useState(false);

  // Zoho state
  const [zohoEmail, setZohoEmail] = useState(zohoConfig.email || '');
  const [zohoPassword, setZohoPassword] = useState(zohoConfig.password || '');
  const [zohoHost, setZohoHost] = useState(zohoConfig.host || 'imap.zoho.eu');
  const [showZohoPass, setShowZohoPass] = useState(false);

  // Testing status
  const [isTestingZoho, setIsTestingZoho] = useState(false);
  const [testResult, setTestResult] = useState<{ success: boolean; message: string } | null>(null);

  const [saved, setSaved] = useState(false);

  if (!isOpen) return null;

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    onSaveGeminiKey(apiKey.trim());
    onSaveZohoConfig({
      email: zohoEmail.trim(),
      password: zohoPassword.trim(),
      host: zohoHost.trim() || 'imap.zoho.eu',
      port: 993,
    });
    setSaved(true);
    setTimeout(() => {
      setSaved(false);
      onClose();
    }, 1200);
  };

  const handleTestZoho = async () => {
    setIsTestingZoho(true);
    setTestResult(null);

    try {
      const res = await fetch('/api/bookings/test', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: zohoEmail.trim(),
          password: zohoPassword.trim(),
          host: zohoHost.trim() || 'imap.zoho.eu',
        }),
      });
      const data = await res.json();
      setTestResult({
        success: data.success,
        message: data.message || (data.success ? 'Connected successfully!' : 'Connection failed'),
      });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Network test error';
      setTestResult({
        success: false,
        message: `Failed to test connection: ${msg}`,
      });
    } finally {
      setIsTestingZoho(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 backdrop-blur-xs p-4 animate-in fade-in duration-200">
      <div className="w-full max-w-lg rounded-2xl bg-white border border-slate-200 p-5 sm:p-6 shadow-2xl relative max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-slate-100">
          <div className="flex items-center gap-2.5">
            <div className="p-2 rounded-xl bg-indigo-50 text-indigo-600">
              <Server className="h-5 w-5" />
            </div>
            <div>
              <h3 className="text-lg font-bold text-slate-900">App Settings</h3>
              <p className="text-xs text-slate-500">Configure Zoho Mail & AI Review engine</p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Tab selection */}
        <div className="flex items-center gap-2 mt-4 p-1 rounded-xl bg-slate-100 border border-slate-200">
          <button
            type="button"
            onClick={() => setActiveTab('zoho')}
            className={`flex-1 flex items-center justify-center gap-1.5 py-2 px-3 rounded-lg text-xs font-bold transition-all ${
              activeTab === 'zoho'
                ? 'bg-white text-indigo-700 shadow-xs border border-slate-200'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <Mail className="h-3.5 w-3.5" />
            <span>Zoho Mail (Bookings)</span>
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('gemini')}
            className={`flex-1 flex items-center justify-center gap-1.5 py-2 px-3 rounded-lg text-xs font-bold transition-all ${
              activeTab === 'gemini'
                ? 'bg-white text-indigo-700 shadow-xs border border-slate-200'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <Sparkles className="h-3.5 w-3.5" />
            <span>Gemini AI Key</span>
          </button>
        </div>

        {/* Body Form */}
        <form onSubmit={handleSave} className="mt-4 space-y-4">
          {/* TAB 1: ZOHO CONFIG */}
          {activeTab === 'zoho' && (
            <div className="space-y-3.5 animate-in fade-in duration-150">
              <div>
                <label className="text-xs font-bold uppercase tracking-wider text-slate-700 block mb-1">
                  Zoho Email Address
                </label>
                <input
                  type="email"
                  value={zohoEmail}
                  onChange={(e) => setZohoEmail(e.target.value)}
                  placeholder="e.g. bookings@alpinetourssalzburg.com"
                  className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-900 placeholder-slate-400 text-xs focus:bg-white focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-colors"
                />
              </div>

              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
                    Zoho App Password
                  </label>
                  <a
                    href="https://accounts.zoho.com/#security/user_app_password"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-[11px] text-indigo-600 hover:text-indigo-700 font-semibold inline-flex items-center gap-1"
                  >
                    <span>Generate App Password</span>
                    <ExternalLink className="h-3 w-3" />
                  </a>
                </div>
                <div className="relative flex items-center">
                  <input
                    type={showZohoPass ? 'text' : 'password'}
                    value={zohoPassword}
                    onChange={(e) => setZohoPassword(e.target.value)}
                    placeholder="xxxx-xxxx-xxxx-xxxx"
                    className="w-full pl-3.5 pr-10 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-900 placeholder-slate-400 text-xs focus:bg-white focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 font-mono transition-colors"
                  />
                  <button
                    type="button"
                    onClick={() => setShowZohoPass(!showZohoPass)}
                    className="absolute right-2.5 text-slate-400 hover:text-slate-700 p-1"
                  >
                    {showZohoPass ? <EyeOff className="h-3.5 w-3.5" /> : <Eye className="h-3.5 w-3.5" />}
                  </button>
                </div>
                <p className="text-[11px] text-slate-500 mt-1 leading-normal">
                  In Zoho, go to <span className="text-slate-700 font-semibold">My Account → Security → App Passwords</span> to generate a dedicated password.
                </p>
              </div>

              <div>
                <label className="text-xs font-bold uppercase tracking-wider text-slate-700 block mb-1">
                  IMAP Mail Server Host
                </label>
                <select
                  value={zohoHost}
                  onChange={(e) => setZohoHost(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-900 text-xs focus:bg-white focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-colors"
                >
                  <option value="imappro.zoho.eu">imappro.zoho.eu (Zoho Mail Lite / Paid Europe - Recommended)</option>
                  <option value="imap.zoho.eu">imap.zoho.eu (Zoho Mail Europe Standard)</option>
                  <option value="imap.zoho.com">imap.zoho.com (Zoho Mail US & Global)</option>
                  <option value="imap.gmail.com">imap.gmail.com (Gmail Forwarding)</option>
                </select>
              </div>

              {/* Test Button & Result */}
              <div className="pt-1">
                <button
                  type="button"
                  onClick={handleTestZoho}
                  disabled={isTestingZoho || !zohoEmail || !zohoPassword}
                  className="w-full py-2.5 px-3 rounded-xl bg-indigo-50 hover:bg-indigo-100 border border-indigo-200 text-indigo-700 text-xs font-bold flex items-center justify-center gap-2 transition-all disabled:opacity-40 cursor-pointer"
                >
                  <RefreshCw className={`h-3.5 w-3.5 ${isTestingZoho ? 'animate-spin' : ''}`} />
                  <span>{isTestingZoho ? 'Testing IMAP Connection...' : 'Test Zoho Connection'}</span>
                </button>

                {testResult && (
                  <div
                    className={`mt-2 p-2.5 rounded-xl border text-xs flex items-start gap-2 ${
                      testResult.success
                        ? 'bg-emerald-50 border-emerald-200 text-emerald-800'
                        : 'bg-rose-50 border-rose-200 text-rose-800'
                    }`}
                  >
                    {testResult.success ? (
                      <CheckCircle2 className="h-4 w-4 shrink-0 mt-0.5 text-emerald-600" />
                    ) : (
                      <AlertCircle className="h-4 w-4 shrink-0 mt-0.5 text-rose-600" />
                    )}
                    <span className="leading-snug font-medium">{testResult.message}</span>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* TAB 2: GEMINI API KEY */}
          {activeTab === 'gemini' && (
            <div className="space-y-3.5 animate-in fade-in duration-150">
              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
                    Google Gemini API Key
                  </label>
                  <a
                    href="https://aistudio.google.com/app/apikey"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-xs text-indigo-600 hover:text-indigo-700 font-semibold inline-flex items-center gap-1"
                  >
                    <span>Get a free key</span>
                    <ExternalLink className="h-3 w-3" />
                  </a>
                </div>

                <div className="relative flex items-center">
                  <input
                    type={showKey ? 'text' : 'password'}
                    value={apiKey}
                    onChange={(e) => setApiKey(e.target.value)}
                    placeholder="AIzaSy..."
                    className="w-full pl-3.5 pr-20 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-slate-900 placeholder-slate-400 text-xs focus:bg-white focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 font-mono transition-colors"
                  />
                  <div className="absolute right-2 flex items-center gap-1">
                    <button
                      type="button"
                      onClick={() => setShowKey(!showKey)}
                      className="p-1.5 text-slate-400 hover:text-slate-700 rounded-lg transition-colors"
                      title={showKey ? 'Hide key' : 'Show key'}
                    >
                      {showKey ? <EyeOff className="h-3.5 w-3.5" /> : <Eye className="h-3.5 w-3.5" />}
                    </button>
                  </div>
                </div>
                <p className="text-[11px] text-slate-500 mt-1 flex items-center gap-1">
                  <Shield className="h-3 w-3 text-emerald-600 shrink-0" />
                  <span>Configured key is saved securely in local browser storage.</span>
                </p>
              </div>

              {/* Info callout */}
              <div className="p-3 rounded-xl bg-indigo-50 border border-indigo-100 space-y-2 text-xs text-indigo-900">
                <div className="flex items-start gap-2">
                  <Info className="h-3.5 w-3.5 text-indigo-600 shrink-0 mt-0.5" />
                  <p>
                    Keys can also be configured permanently in <code className="text-indigo-800 bg-indigo-100/60 font-semibold px-1 py-0.5 rounded">.env.local</code>.
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* Footer buttons */}
          <div className="pt-3 border-t border-slate-100 flex items-center justify-between">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-600 hover:text-slate-900 bg-slate-100 hover:bg-slate-200 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="inline-flex items-center gap-1.5 px-5 py-2.5 rounded-xl text-xs font-bold bg-indigo-600 hover:bg-indigo-700 text-white transition-colors shadow-sm"
            >
              {saved ? (
                <>
                  <Check className="h-3.5 w-3.5" />
                  <span>Saved!</span>
                </>
              ) : (
                <span>Save All Settings</span>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
