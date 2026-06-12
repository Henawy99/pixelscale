'use client';
import Link from 'next/link';
import { useState } from 'react';

export default function Header() {
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <header className="header">
      <div className="header-inner">
        <Link href="/" className="logo">Konsumenten<span>retter</span></Link>
        <nav className={`nav ${menuOpen ? 'nav-open' : ''}`}>
          <Link href="/anspruch-pruefen/kredit" onClick={() => setMenuOpen(false)}>Kreditgebühren</Link>
          <Link href="/anspruch-pruefen/telekom" onClick={() => setMenuOpen(false)}>Servicepauschalen</Link>
          <Link href="/anspruch-pruefen/casino" onClick={() => setMenuOpen(false)}>Online Casino</Link>
          <Link href="/#ablauf" onClick={() => setMenuOpen(false)}>Ablauf</Link>
          <Link href="/impressum" onClick={() => setMenuOpen(false)}>Impressum</Link>
          <Link href="/anspruch-pruefen" className="btn btn-primary btn-sm nav-cta nav-cta-mobile" onClick={() => setMenuOpen(false)}>Anspruch prüfen</Link>
        </nav>
        <Link href="/anspruch-pruefen" className="btn btn-primary btn-sm nav-cta nav-cta-desktop">Anspruch prüfen</Link>
        <button className="nav-mobile-btn" onClick={() => setMenuOpen(!menuOpen)} aria-label="Menü">
          {menuOpen ? '✕' : '☰'}
        </button>
      </div>
    </header>
  );
}
