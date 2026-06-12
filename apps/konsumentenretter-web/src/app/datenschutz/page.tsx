import Header from '@/components/Header';
import Footer from '@/components/Footer';

export const metadata = { title: 'Datenschutz – Konsumentenretter' };

export default function DatenschutzPage() {
  return (
    <>
      <Header />
      <div className="form-page">
        <div className="form-hero"><h1>Datenschutzerklärung</h1></div>
        <div className="form-container">
          <div className="form-card" style={{ fontSize: '0.9rem', lineHeight: 1.8, color: 'var(--gray-600)' }}>
            <h2 style={{ fontSize: '1.1rem', marginBottom: 12 }}>1. Personenbezogene Daten</h2>
            <p>Wir erheben, verarbeiten und nutzen Ihre personenbezogenen Daten nur mit Ihrer Einwilligung und im Einklang mit der DSGVO. Es werden nur solche Daten erhoben, die für die Durchführung unserer Dienstleistungen erforderlich sind.</p>
            <br />
            <h2 style={{ fontSize: '1.1rem', marginBottom: 12 }}>2. Auskunft und Löschung</h2>
            <p>Sie haben jederzeit das Recht auf Auskunft, Berichtigung, Löschung und Einschränkung der Verarbeitung Ihrer Daten.</p>
            <br />
            <h2 style={{ fontSize: '1.1rem', marginBottom: 12 }}>3. Datensicherheit</h2>
            <p>Der Schutz Ihrer personenbezogenen Daten erfolgt durch entsprechende organisatorische und technische Vorkehrungen.</p>
            <br />
            <h2 style={{ fontSize: '1.1rem', marginBottom: 12 }}>4. Cookies</h2>
            <p>Diese Website verwendet Cookies, um unser Angebot nutzerfreundlicher zu gestalten.</p>
            <br />
            <h2 style={{ fontSize: '1.1rem', marginBottom: 12 }}>5. Kontakt</h2>
            <p>Bei Fragen zum Datenschutz kontaktieren Sie uns unter: office@konsumentenretter.at</p>
          </div>
        </div>
      </div>
      <Footer />
    </>
  );
}
