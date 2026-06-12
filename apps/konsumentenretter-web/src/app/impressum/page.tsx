import Header from '@/components/Header';
import Footer from '@/components/Footer';

export const metadata = { title: 'Impressum – Konsumentenretter' };

export default function ImpressumPage() {
  return (
    <>
      <Header />
      <div className="form-page">
        <div className="form-hero"><h1>Impressum</h1></div>
        <div className="form-container">
          <div className="form-card" style={{ fontSize: '0.95rem', lineHeight: 1.8 }}>
            <h2 style={{ fontSize: '1.2rem', marginBottom: 16 }}>Angaben gemäß § 5 ECG</h2>
            <p><strong>Konsumentenretter</strong><br />Musterstraße 1<br />1010 Wien, Österreich</p>
            <br />
            <p><strong>Kontakt:</strong><br />E-Mail: office@konsumentenretter.at</p>
            <br />
            <p><strong>Berufsrecht:</strong><br />Es gelten die einschlägigen österreichischen Gesetze und Bestimmungen.</p>
            <br />
            <p style={{ color: 'var(--gray-400)', fontStyle: 'italic' }}>Diese Seite wird aktualisiert, sobald alle Unternehmensangaben vorliegen.</p>
          </div>
        </div>
      </div>
      <Footer />
    </>
  );
}
