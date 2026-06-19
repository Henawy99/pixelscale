'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';

const links = [
  { href: '/dashboard', icon: '📊', label: 'Dashboard' },
  { href: '/leads', icon: '👥', label: 'Leads' },
  { href: '/status', icon: '📋', label: 'Status (Kanban)' },
  { href: '/team', icon: '🏗️', label: 'Team' },
  { href: '/links', icon: '🔗', label: 'Ref-Links' },
  { href: '/billing', icon: '💰', label: 'Abrechnung' },
  { href: '/settings', icon: '⚙️', label: 'Einstellungen' },
];

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const [partner, setPartner] = useState({ name: 'Demo Partner', email: 'partner@beispiel.at' });
  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => {
    if (typeof window !== 'undefined') {
      const stored = localStorage.getItem('kr_partner');
      if (stored) {
        try {
          const parsed = JSON.parse(stored);
          if (parsed.name && parsed.email) {
            setPartner({ name: parsed.name, email: parsed.email });
          }
        } catch (e) {
          console.warn('Failed to parse kr_partner', e);
        }
      }
    }
  }, []);

  const initials = partner.name
    .split(' ')
    .map(n => n[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);

  return (
    <>
      {/* Mobile Top Header */}
      <header className="mobile-header">
        <button className="mobile-menu-btn" onClick={() => setIsOpen(true)} aria-label="Menü öffnen">
          ☰
        </button>
        <div className="mobile-header-brand">
          <h2>Konsumenten<span>retter</span></h2>
        </div>
      </header>

      {/* Backdrop overlay for mobile menu */}
      {isOpen && (
        <div className="mobile-sidebar-overlay" onClick={() => setIsOpen(false)} />
      )}

      {/* Sidebar (handles desktop and mobile layout) */}
      <aside className={`sidebar ${isOpen ? 'mobile-open' : ''}`}>
        <div className="sidebar-brand">
          <h2>Konsumenten<span>retter</span></h2>
          <p>Partner Portal</p>
          <button className="mobile-close-btn" onClick={() => setIsOpen(false)} aria-label="Menü schließen">
            ✕
          </button>
        </div>
        <nav className="sidebar-nav">
          {links.map(l => (
            <Link 
              key={l.href} 
              href={l.href} 
              className={`sidebar-link ${pathname === l.href ? 'active' : ''}`}
              onClick={() => setIsOpen(false)}
            >
              <span className="icon">{l.icon}</span> {l.label}
            </Link>
          ))}
        </nav>
        <div className="sidebar-footer">
          <div className="sidebar-user" style={{ marginBottom: '12px' }}>
            <div className="sidebar-avatar">{initials || 'DP'}</div>
            <div className="sidebar-user-info">
              <p>{partner.name}</p>
              <span>{partner.email}</span>
            </div>
          </div>
          <button 
            onClick={async () => {
              if (typeof window !== 'undefined') {
                localStorage.removeItem('kr_partner');
                try {
                  await supabase.auth.signOut();
                } catch (e) {
                  console.warn('Failed to sign out from Supabase', e);
                }
                router.push('/');
              }
            }} 
            className="sidebar-link" 
            style={{ 
              color: 'var(--red)', 
              background: 'rgba(239, 68, 68, 0.08)',
              padding: '8px 12px',
              borderRadius: 'var(--radius-sm)',
              fontSize: '0.85rem',
              width: '100%',
              display: 'flex',
              alignItems: 'center',
              gap: '10px',
              border: 'none',
              cursor: 'pointer',
              fontWeight: 600,
              transition: 'var(--transition)'
            }}
          >
            <span className="icon" style={{ fontSize: '1rem' }}>🚪</span> Abmelden
          </button>
        </div>
      </aside>
    </>
  );
}

