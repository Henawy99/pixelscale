'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState, useEffect } from 'react';

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
          <div className="sidebar-user">
            <div className="sidebar-avatar">{initials || 'DP'}</div>
            <div className="sidebar-user-info">
              <p>{partner.name}</p>
              <span>{partner.email}</span>
            </div>
          </div>
        </div>
      </aside>
    </>
  );
}

