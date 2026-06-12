'use client';
import { useState, useEffect } from 'react';
import Sidebar from '@/components/Sidebar';
import { supabase } from '@/lib/supabase';

export default function LinksPage() {
  const [copied, setCopied] = useState('');
  const [refCode, setRefCode] = useState('HASHIM2026');

  useEffect(() => {
    async function loadRefCode() {
      const stored = localStorage.getItem('kr_partner');
      if (stored) {
        try {
          const partner = JSON.parse(stored);
          if (partner.id === 'admin-root') {
            setRefCode('ref_hashim_admin');
            return;
          }
          const { data, error } = await supabase
            .from('partners')
            .select('ref_code')
            .eq('id', partner.id)
            .single();

          if (data?.ref_code) {
            setRefCode(data.ref_code);
          }
        } catch (e) {
          console.error("Failed to load partner ref_code:", e);
        }
      }
    }
    loadRefCode();
  }, []);

  const copy = (url: string, key: string) => {
    navigator.clipboard.writeText(url);
    setCopied(key);
    setTimeout(() => setCopied(''), 2000);
  };

  const links = [
    { key: 'credit', icon: '🏦', title: 'Kreditbearbeitungsgebühren', url: `https://konsumentenretter-web.vercel.app/anspruch-pruefen/kredit?ref=${refCode}` },
    { key: 'service', icon: '📱', title: 'Servicepauschalen', url: `https://konsumentenretter-web.vercel.app/anspruch-pruefen/telekom?ref=${refCode}` },
    { key: 'casino', icon: '🎰', title: 'Online Casino', url: `https://konsumentenretter-web.vercel.app/anspruch-pruefen/casino?ref=${refCode}` },
  ];

  return (
    <div className="app-layout">
      <Sidebar />
      <main className="main-content">
        <div className="page-header"><h1>Meine Ref-Links</h1></div>
        <div className="stat-card" style={{ marginBottom: 24 }}>
          <p style={{ fontSize: '0.9rem', color: 'var(--gray-500)' }}>Dein persönlicher Ref-Code: <strong style={{ color: 'var(--teal)', fontSize: '1.1rem' }}>{refCode}</strong></p>
        </div>
        <div className="ref-links-grid">
          {links.map(l => (
            <div key={l.key} className="ref-link-card">
              <h3>{l.icon} {l.title}</h3>
              <div className="ref-link-url">
                <input readOnly value={l.url} />
                <button className="btn btn-primary btn-sm" onClick={() => copy(l.url, l.key)}>
                  {copied === l.key ? '✓ Kopiert' : 'Kopieren'}
                </button>
              </div>
            </div>
          ))}
        </div>
      </main>
    </div>
  );
}
