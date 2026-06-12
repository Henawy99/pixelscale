import Link from 'next/link';

export default function Footer() {
  return (
    <footer className="footer">
      <div className="footer-grid">
        <div className="footer-brand">
          <Link href="/" className="logo">Konsumenten<span>retter</span></Link>
          <p>Wir setzen Konsumentenrechte in Österreich durch – kostenlos, digital und ohne Prozessrisiko für Sie.</p>
        </div>
        <div className="footer-links">
          <h4>Verfahren</h4>
          <Link href="/anspruch-pruefen/kredit">Kreditgebühren</Link>
          <Link href="/anspruch-pruefen/telekom">Servicepauschalen</Link>
          <Link href="/anspruch-pruefen/casino">Online Casino</Link>
        </div>
        <div className="footer-links">
          <h4>Unternehmen</h4>
          <Link href="/#ablauf">Ablauf</Link>
          <Link href="/kontakt">Kontakt</Link>
          <Link href="/impressum">Impressum</Link>
        </div>
        <div className="footer-links">
          <h4>Rechtliches</h4>
          <Link href="/datenschutz">Datenschutz</Link>
          <Link href="/agb">AGB</Link>
          <Link href="/cookies">Cookies</Link>
        </div>
      </div>
      <div className="footer-bottom">
        <p>© 2025 Konsumentenretter. Alle Rechte vorbehalten.</p>
      </div>
    </footer>
  );
}
