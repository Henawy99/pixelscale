'use client';
import { useState, useEffect, Suspense } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import SignaturePad from '@/components/SignaturePad';
import FileUpload from '@/components/FileUpload';

const PROVIDERS = ['A1', 'Magenta', 'Andere'];
const INSURERS = ['UNIQA', 'Generali', 'Allianz', 'D.A.S.', 'ARAG', 'Wiener Städtische - Donau', 'Helvetia', 'Zurich', 'Andere'];

export default function ServicepauschalenPage() {
  return (<Suspense fallback={<div style={{ minHeight: '100vh', background: '#14532d' }} />}><ServicepauschalenForm /></Suspense>);
}

function ServicepauschalenForm() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const ref = searchParams.get('ref');
  const [submitting, setSubmitting] = useState(false);
  const [form, setForm] = useState({
    firstName: '', lastName: '', email: '', birthDay: '', birthMonth: '', birthYear: '',
    street: '', city: '', postalCode: '', phone: '',
    providers: [] as string[], hasInsurance: '',
    insuranceProvider: '', hasInvoice: '',
    confirmLegal: false, confirmNewsletter: false,
    signature: '', ausweisFiles: [] as File[], rechnungFiles: [] as File[],
  });

  useEffect(() => { if (ref) localStorage.setItem('kr_ref', ref); }, [ref]);

  const toggleProvider = (p: string) => {
    setForm(f => ({ ...f, providers: f.providers.includes(p) ? f.providers.filter(x => x !== p) : [...f.providers, p] }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      console.log('Servicepauschalen submission:', { ...form, ref: ref || localStorage.getItem('kr_ref') });
      router.push('/danke');
    } catch { alert('Fehler aufgetreten.'); } finally { setSubmitting(false); }
  };

  return (
    <>
      <Header />
      <div className="form-page">
        <div className="form-hero" style={{ background: 'linear-gradient(135deg, #14532d, #16a34a)' }}>
          <div className="hero-badge" style={{ background: 'rgba(255,255,255,0.1)', borderColor: 'rgba(255,255,255,0.2)', color: '#fff' }}>📱 Handy- &amp; Internetverträge</div>
          <h1>Servicepauschalen zurückfordern</h1>
          <p>Servicepauschalen sind Zusatzentgelte ohne Gegenleistung – und damit unzulässig.</p>
        </div>
        <div className="form-container">
          <div className="info-box">
            <p>Servicepauschalen bei Handy- und Internetverträgen sind rechtswidrig. Füllen Sie das Formular aus – <strong>kostenlos und unverbindlich</strong>.</p>
          </div>
          <form className="form-card" onSubmit={handleSubmit}>
            <div className="form-section">
              <div className="form-section-title">Persönliche Daten</div>
              <div className="form-row">
                <div className="form-group"><label>Vorname <span className="required">*</span></label><input className="form-input" required value={form.firstName} onChange={e => setForm(f => ({ ...f, firstName: e.target.value }))} /></div>
                <div className="form-group"><label>Nachname <span className="required">*</span></label><input className="form-input" required value={form.lastName} onChange={e => setForm(f => ({ ...f, lastName: e.target.value }))} /></div>
              </div>
              <div className="form-group"><label>E-Mail <span className="required">*</span></label><input className="form-input" type="email" required value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))} /></div>
              <div className="form-group"><label>Geburtsdatum <span className="required">*</span></label>
                <div className="form-row" style={{ gridTemplateColumns: '1fr 1fr 1fr' }}>
                  <input className="form-input" required placeholder="TT" maxLength={2} value={form.birthDay} onChange={e => setForm(f => ({ ...f, birthDay: e.target.value }))} />
                  <input className="form-input" required placeholder="MM" maxLength={2} value={form.birthMonth} onChange={e => setForm(f => ({ ...f, birthMonth: e.target.value }))} />
                  <input className="form-input" required placeholder="JJJJ" maxLength={4} value={form.birthYear} onChange={e => setForm(f => ({ ...f, birthYear: e.target.value }))} />
                </div>
              </div>
              <div className="form-group"><label>Straße und Hausnummer <span className="required">*</span></label><input className="form-input" required value={form.street} onChange={e => setForm(f => ({ ...f, street: e.target.value }))} /></div>
              <div className="form-row">
                <div className="form-group"><label>Ort <span className="required">*</span></label><input className="form-input" required value={form.city} onChange={e => setForm(f => ({ ...f, city: e.target.value }))} /></div>
                <div className="form-group"><label>PLZ <span className="required">*</span></label><input className="form-input" required value={form.postalCode} onChange={e => setForm(f => ({ ...f, postalCode: e.target.value }))} /></div>
              </div>
              <div className="form-group"><label>Telefonnummer <span className="required">*</span></label><input className="form-input" type="tel" required value={form.phone} onChange={e => setForm(f => ({ ...f, phone: e.target.value }))} placeholder="+43..." /></div>
            </div>
            <div className="form-section">
              <div className="form-section-title">Bei welchem Anbieter?</div>
              <div className="form-checkbox-group">
                {PROVIDERS.map(p => (<label key={p} className={`form-checkbox ${form.providers.includes(p) ? 'selected' : ''}`}><input type="checkbox" checked={form.providers.includes(p)} onChange={() => toggleProvider(p)} /><span>{p}</span></label>))}
              </div>
            </div>
            <div className="form-section">
              <div className="form-section-title">Rechtsschutzversicherung? <span className="required">*</span></div>
              <div className="form-radio-group">
                {['Ja', 'Nein'].map(v => (<label key={v} className={`form-radio ${form.hasInsurance === v ? 'selected' : ''}`}><input type="radio" name="insurance" value={v} checked={form.hasInsurance === v} onChange={e => setForm(f => ({ ...f, hasInsurance: e.target.value }))} /><span>{v}</span></label>))}
              </div>
              {form.hasInsurance === 'Ja' && (<div className="form-group" style={{ marginTop: 16 }}><label>Versicherungsanbieter</label><select className="form-select" value={form.insuranceProvider} onChange={e => setForm(f => ({ ...f, insuranceProvider: e.target.value }))}><option value="">Bitte auswählen...</option>{INSURERS.map(i => <option key={i} value={i}>{i}</option>)}</select></div>)}
            </div>
            <div className="form-section">
              <div className="form-section-title">Bestätigungen</div>
              <div className="form-checkbox-group">
                <label className={`form-checkbox ${form.confirmLegal ? 'selected' : ''}`}><input type="checkbox" required checked={form.confirmLegal} onChange={e => setForm(f => ({ ...f, confirmLegal: e.target.checked }))} /><span>Ich bestätige, dass ich die Vollmachten sowie den Vollfinanzierungsantrag gelesen und verstanden habe. <span className="required">*</span></span></label>
                <label className={`form-checkbox ${form.confirmNewsletter ? 'selected' : ''}`}><input type="checkbox" checked={form.confirmNewsletter} onChange={e => setForm(f => ({ ...f, confirmNewsletter: e.target.checked }))} /><span>Ich möchte den Newsletter erhalten.</span></label>
              </div>
            </div>
            <div className="form-section">
              <div className="form-section-title">Dokumente hochladen</div>
              <FileUpload label="Ausweis" required onChange={files => setForm(f => ({ ...f, ausweisFiles: files }))} />
              <FileUpload label="Aktuelle Handyrechnung" onChange={files => setForm(f => ({ ...f, rechnungFiles: files }))} />
            </div>
            <div className="form-section">
              <div className="form-section-title">Unterschrift <span className="required">*</span></div>
              <SignaturePad onChange={sig => setForm(f => ({ ...f, signature: sig }))} />
            </div>
            <div className="form-submit"><button type="submit" className="btn btn-gold" disabled={submitting}>{submitting ? 'Wird gesendet...' : 'Senden ✓'}</button></div>
          </form>
        </div>
      </div>
      <Footer />
    </>
  );
}
