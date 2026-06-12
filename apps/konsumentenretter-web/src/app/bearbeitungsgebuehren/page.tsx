'use client';
import { useState, useEffect, Suspense } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import SignaturePad from '@/components/SignaturePad';
import FileUpload from '@/components/FileUpload';

const BANKS = ['Wüstenrot', 'BAWAG', 'Bank Austria', 'Erste/Sparkasse', 'Raiffeisen', 'Oberbank', 'Santander', 'Volksbank', 'Andere'];
const INSURERS = ['UNIQA', 'Generali', 'Allianz', 'D.A.S.', 'ARAG', 'Wiener Städtische - Donau', 'Helvetia', 'Zurich', 'Andere'];

export default function BearbeitungsgebuehrenPage() {
  return (
    <Suspense fallback={<div style={{ minHeight: '100vh', background: '#0A1628' }} />}>
      <BearbeitungsgebuehrenForm />
    </Suspense>
  );
}

function BearbeitungsgebuehrenForm() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const ref = searchParams.get('ref');
  const [submitting, setSubmitting] = useState(false);
  const [form, setForm] = useState({
    firstName: '', lastName: '', email: '', birthDay: '', birthMonth: '', birthYear: '',
    street: '', city: '', postalCode: '', phone: '',
    banks: [] as string[], hasInsurance: '' as string,
    insuranceProvider: '', hasContract: '' as string,
    confirmLegal: false, confirmNewsletter: false,
    signature: '', ausweisFiles: [] as File[], vertragFiles: [] as File[],
  });
  const [openLegal, setOpenLegal] = useState<string | null>(null);

  useEffect(() => {
    if (ref) localStorage.setItem('kr_ref', ref);
  }, [ref]);

  const toggleBank = (b: string) => {
    setForm(f => ({ ...f, banks: f.banks.includes(b) ? f.banks.filter(x => x !== b) : [...f.banks, b] }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      const refCode = ref || localStorage.getItem('kr_ref') || null;
      // For now, store in localStorage as demo. Supabase integration when keys are provided.
      const submission = {
        campaign: 'bearbeitungsgebuehren',
        ref: refCode,
        ...form,
        birthDate: `${form.birthYear}-${form.birthMonth}-${form.birthDay}`,
        ausweisFiles: form.ausweisFiles.map(f => f.name),
        vertragFiles: form.vertragFiles.map(f => f.name),
        submittedAt: new Date().toISOString(),
      };
      console.log('Submission:', submission);
      router.push('/danke');
    } catch (err) {
      console.error(err);
      alert('Ein Fehler ist aufgetreten. Bitte versuchen Sie es erneut.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <>
      <Header />
      <div className="form-page">
        <div className="form-hero">
          <div className="hero-badge">🏦 Kreditvertragsgebühren</div>
          <h1>Wir holen deine Bearbeitungsgebühren<br />von Kreditverträgen zurück.</h1>
          <p>Kostenlos &amp; ohne Risiko</p>
        </div>

        <div className="form-container">
          <div className="info-box">
            <p>Die Anmeldung ist <strong>unverbindlich und kostenlos</strong>. Füllen Sie einfach das Formular aus – wir kümmern uns um den Rest. Im Erfolgsfall erhalten Sie 64,5 % des erzielten Erlöses.</p>
          </div>

          <form className="form-card" onSubmit={handleSubmit}>
            {/* Personal Data */}
            <div className="form-section">
              <div className="form-section-title">Persönliche Daten</div>
              <div className="form-row">
                <div className="form-group">
                  <label>Vorname <span className="required">*</span></label>
                  <input className="form-input" required value={form.firstName} onChange={e => setForm(f => ({ ...f, firstName: e.target.value }))} placeholder="Max" />
                </div>
                <div className="form-group">
                  <label>Nachname <span className="required">*</span></label>
                  <input className="form-input" required value={form.lastName} onChange={e => setForm(f => ({ ...f, lastName: e.target.value }))} placeholder="Mustermann" />
                </div>
              </div>
              <div className="form-group">
                <label>E-Mail <span className="required">*</span></label>
                <input className="form-input" type="email" required value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))} placeholder="max@beispiel.at" />
              </div>
              <div className="form-group">
                <label>Geburtsdatum <span className="required">*</span></label>
                <div className="form-row" style={{ gridTemplateColumns: '1fr 1fr 1fr' }}>
                  <input className="form-input" required placeholder="TT" maxLength={2} value={form.birthDay} onChange={e => setForm(f => ({ ...f, birthDay: e.target.value }))} />
                  <input className="form-input" required placeholder="MM" maxLength={2} value={form.birthMonth} onChange={e => setForm(f => ({ ...f, birthMonth: e.target.value }))} />
                  <input className="form-input" required placeholder="JJJJ" maxLength={4} value={form.birthYear} onChange={e => setForm(f => ({ ...f, birthYear: e.target.value }))} />
                </div>
              </div>
              <div className="form-group">
                <label>Straße und Hausnummer <span className="required">*</span></label>
                <input className="form-input" required value={form.street} onChange={e => setForm(f => ({ ...f, street: e.target.value }))} />
              </div>
              <div className="form-row">
                <div className="form-group">
                  <label>Ort <span className="required">*</span></label>
                  <input className="form-input" required value={form.city} onChange={e => setForm(f => ({ ...f, city: e.target.value }))} />
                </div>
                <div className="form-group">
                  <label>PLZ <span className="required">*</span></label>
                  <input className="form-input" required value={form.postalCode} onChange={e => setForm(f => ({ ...f, postalCode: e.target.value }))} />
                </div>
              </div>
              <div className="form-group">
                <label>Telefonnummer <span className="required">*</span></label>
                <input className="form-input" type="tel" required value={form.phone} onChange={e => setForm(f => ({ ...f, phone: e.target.value }))} placeholder="+43..." />
              </div>
            </div>

            {/* Bank Selection */}
            <div className="form-section">
              <div className="form-section-title">Bei welcher Bank besteht der Kreditvertrag?</div>
              <div className="form-checkbox-group">
                {BANKS.map(b => (
                  <label key={b} className={`form-checkbox ${form.banks.includes(b) ? 'selected' : ''}`}>
                    <input type="checkbox" checked={form.banks.includes(b)} onChange={() => toggleBank(b)} />
                    <span>{b}</span>
                  </label>
                ))}
              </div>
            </div>

            {/* Insurance */}
            <div className="form-section">
              <div className="form-section-title">Besteht eine Rechtsschutzversicherung? <span className="required">*</span></div>
              <div className="form-radio-group">
                {['Ja', 'Nein'].map(v => (
                  <label key={v} className={`form-radio ${form.hasInsurance === v ? 'selected' : ''}`}>
                    <input type="radio" name="insurance" value={v} checked={form.hasInsurance === v} onChange={e => setForm(f => ({ ...f, hasInsurance: e.target.value }))} />
                    <span>{v}</span>
                  </label>
                ))}
              </div>
              {form.hasInsurance === 'Ja' && (
                <div className="form-group" style={{ marginTop: 16 }}>
                  <label>Versicherungsanbieter</label>
                  <select className="form-select" value={form.insuranceProvider} onChange={e => setForm(f => ({ ...f, insuranceProvider: e.target.value }))}>
                    <option value="">Bitte auswählen...</option>
                    {INSURERS.map(i => <option key={i} value={i}>{i}</option>)}
                  </select>
                </div>
              )}
            </div>

            {/* Confirmations */}
            <div className="form-section">
              <div className="form-section-title">Bestätigungen</div>
              <div className="form-checkbox-group">
                <label className={`form-checkbox ${form.confirmLegal ? 'selected' : ''}`}>
                  <input type="checkbox" required checked={form.confirmLegal} onChange={e => setForm(f => ({ ...f, confirmLegal: e.target.checked }))} />
                  <span>Ich bestätige, dass ich die unten stehenden Vollmachten sowie den Vollfinanzierungsantrag samt Anlagen gelesen und verstanden habe. <span className="required">*</span></span>
                </label>
                <label className={`form-checkbox ${form.confirmNewsletter ? 'selected' : ''}`}>
                  <input type="checkbox" checked={form.confirmNewsletter} onChange={e => setForm(f => ({ ...f, confirmNewsletter: e.target.checked }))} />
                  <span>Ich möchte den Newsletter erhalten und bin mit der Verarbeitung meiner Daten zum Versand einverstanden.</span>
                </label>
              </div>
            </div>

            {/* File Uploads */}
            <div className="form-section">
              <div className="form-section-title">Dokumente hochladen</div>
              <p style={{ fontSize: '0.9rem', color: 'var(--gray-500)', marginBottom: 20 }}>
                Laden Sie bitte eine Kopie Ihres Ausweises sowie Ihres Kreditvertrags hoch.
              </p>
              <FileUpload label="Ausweis" required onChange={files => setForm(f => ({ ...f, ausweisFiles: files }))} />
              <FileUpload label="Kreditvertrag" onChange={files => setForm(f => ({ ...f, vertragFiles: files }))} />
            </div>

            {/* Signature */}
            <div className="form-section">
              <div className="form-section-title">Unterschrift <span className="required">*</span></div>
              <p style={{ fontSize: '0.85rem', color: 'var(--gray-500)', marginBottom: 12 }}>
                Bitte Ihre offizielle Unterschrift verwenden
              </p>
              <SignaturePad onChange={sig => setForm(f => ({ ...f, signature: sig }))} />
            </div>

            {/* Legal Sections */}
            <div className="legal-section">
              <h3 style={{ fontSize: '1rem', marginBottom: 12 }}>Vollmachten</h3>
              {[
                { key: 'vollmacht', label: 'Vollmacht', content: 'Hiermit erteile ich als Auftraggeber/in Prozessvollmacht und bevollmächtige den Auftragnehmer mich in allen Angelegenheiten zu vertreten...' },
                { key: 'datenschutz', label: 'Datenschutzerklärung', content: 'Personenbezogene Daten werden nur mit Ihrer Einwilligung und im Einklang mit der DSGVO verarbeitet...' },
              ].map(item => (
                <div key={item.key} className="legal-group">
                  <button type="button" className="legal-toggle" onClick={() => setOpenLegal(openLegal === item.key ? null : item.key)}>
                    {item.label}
                    <span className={`legal-toggle-icon ${openLegal === item.key ? 'open' : ''}`}>▼</span>
                  </button>
                  <div className={`legal-content ${openLegal === item.key ? 'open' : ''}`}>{item.content}</div>
                </div>
              ))}
              <h3 style={{ fontSize: '1rem', marginTop: 20, marginBottom: 12 }}>Vollfinanzierungsantrag</h3>
              {[
                { key: 'vertrag', label: 'Vertrag Prozessfinanzierung', content: 'Der Prozessfinanzierer übernimmt sämtliche Kosten und Risiken. Im Erfolgsfall erhalten Sie 64,5% des erzielten Erlöses...' },
                { key: 'anhang', label: 'Anhang II', content: 'Datenschutzbestimmungen zum Prozessfinanzierungsvertrag...' },
                { key: 'merkblatt', label: 'Merkblatt zur Datenverarbeitung', content: 'Informationen über die Verarbeitung Ihrer personenbezogenen Daten durch den Prozessfinanzierer...' },
                { key: 'widerruf', label: 'Informationen zur Ausübung des Widerrufrechts', content: 'Sie haben das Recht, binnen vierzehn Tagen ohne Angabe von Gründen diesen Vertrag zu widerrufen...' },
              ].map(item => (
                <div key={item.key} className="legal-group">
                  <button type="button" className="legal-toggle" onClick={() => setOpenLegal(openLegal === item.key ? null : item.key)}>
                    {item.label}
                    <span className={`legal-toggle-icon ${openLegal === item.key ? 'open' : ''}`}>▼</span>
                  </button>
                  <div className={`legal-content ${openLegal === item.key ? 'open' : ''}`}>{item.content}</div>
                </div>
              ))}
            </div>

            {/* Submit */}
            <div className="form-submit">
              <button type="submit" className="btn btn-gold" disabled={submitting}>
                {submitting ? 'Wird gesendet...' : 'Senden ✓'}
              </button>
            </div>
          </form>
        </div>
      </div>
      <Footer />
    </>
  );
}
