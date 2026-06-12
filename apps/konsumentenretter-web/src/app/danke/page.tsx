import Link from 'next/link';
import Header from '@/components/Header';

export default function DankePage() {
  return (
    <>
      <Header />
      <div className="success-page">
        <div className="success-card">
          <div className="success-icon">✅</div>
          <h1>Vielen Dank!</h1>
          <p>Ihre Anmeldung wurde erfolgreich übermittelt. Wir werden Ihren Fall prüfen und uns in Kürze bei Ihnen melden.</p>
          <Link href="/" className="btn btn-primary">Zurück zur Startseite</Link>
        </div>
      </div>
    </>
  );
}
