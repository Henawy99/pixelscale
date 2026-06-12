'use client';
import { useState, useEffect, Suspense } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import SignaturePad from '@/components/SignaturePad';
import FileUpload from '@/components/FileUpload';

const INSURERS = ['UNIQA', 'Generali', 'Allianz', 'D.A.S.', 'ARAG', 'Wiener Städtische - Donau', 'Helvetia', 'Zurich', 'Andere'];

export default function OnlineCasinoPage() {
  return (<Suspense fallback={<div style={{ minHeight: '100vh', background: '#4c1d95' }} />}><OnlineCasinoForm /></Suspense>);
}

function OnlineCasinoForm() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const ref = searchParams.get('ref');
  const [submitting, setSubmitting] = useState(false);
  const [form, setForm] = useState({
    firstName: '', lastName: '', email: '', birthDay: '', birthMonth: '', birthYear: '',
    street: '', city: '', postalCode: '', phone: '',
    casinoNames: '', estimatedLosses: '', hasInsurance: '',
    insuranceProvider: '',
    confirmAustria: false, confirmNoLawyer: false, confirmStopPlaying: false,
    confirmLegal: false,
    signature: '', ausweisFiles: [] as File[], transaktionFiles: [] as File[],
  });

  useEffect(() => { if (ref) localStorage.setItem('kr_ref', ref); }, [ref]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      console.log('Casino submission:', { ...form, ref: ref || localStorage.getItem('kr_ref') });
      router.push('/danke');
    } catch { alert('Fehler aufgetreten.'); } finally { setSubmitting(false); }
  };

  return (
    <>
      <Header />
      <div className="form-page">
        <div className="form-hero" style={{ background: 'linear-gradient(135deg, #4c1d95, #7c3aed)' }}>
          <div className="hero-badge" style={{ background: 'rgba(255,255,255,0.1)', borderColor: 'rgba(255,255,255,0.2)', color: '#fff' }}>🎰 Online Casino</div>
          <h1>Online Glücksspielverluste<br />zurückfordern</h1>
          <p>Die meisten Online Casinos in Österreich sind illegal. Holen Sie sich Ihre Verluste zurück.</p>
        </div>
        <div className="form-container">
          <div className="info-box">
            <p>Alle Glücksspielverluste (Slots, Poker, Blackjack, Roulette) bei nicht-lizenzierten Anbietern sind <strong>bis zu 30 Jahre rückforderbar</strong>. Sportwetten sind ausgenommen.</p>
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
              <div className="form-section-title">Casino Details</div>
              <div className="form-group"><label>Bei welchen Online Casinos haben Sie gespielt? <span className="required">*</span></label><input className="form-input" required value={form.casinoNames} onChange={e => setForm(f => ({ ...f, casinoNames: e.target.value }))} placeholder="z.B. Bwin, Mr. Green, LeoVegas..." /></div>
              <div className="form-group"><label>Geschätzte Gesamtverluste (€)</label><input className="form-input" type="number" value={form.estimatedLosses} onChange={e => setForm(f => ({ ...f, estimatedLosses: e.target.value }))} placeholder="z.B. 5000" /></div>
            </div>

            <div className="form-section">
              <div className="form-section-title">Rechtsschutzversicherung?</div>
              <div className="form-radio-group">
                {['Ja', 'Nein'].map(v => (<label key={v} className={`form-radio ${form.hasInsurance === v ? 'selected' : ''}`}><input type="radio" name="insurance" value={v} checked={form.hasInsurance === v} onChange={e => setForm(f => ({ ...f, hasInsurance: e.target.value }))} /><span>{v}</span></label>))}
              </div>
              {form.hasInsurance === 'Ja' && (<div className="form-group" style={{ marginTop: 16 }}><label>Versicherungsanbieter</label><select className="form-select" value={form.insuranceProvider} onChange={e => setForm(f => ({ ...f, insuranceProvider: e.target.value }))}><option value="">Bitte auswählen...</option>{INSURERS.map(i => <option key={i} value={i}>{i}</option>)}</select></div>)}
            </div>

            <div className="form-section">
              <div className="form-section-title">Bestätigungen <span className="required">*</span></div>
              <div className="form-checkbox-group">
                <label className={`form-checkbox ${form.confirmAustria ? 'selected' : ''}`}><input type="checkbox" required checked={form.confirmAustria} onChange={e => setForm(f => ({ ...f, confirmAustria: e.target.checked }))} /><span>Ich habe meinen Account in Österreich registriert und in Österreich gespielt.</span></label>
                <label className={`form-checkbox ${form.confirmNoLawyer ? 'selected' : ''}`}><input type="checkbox" required checked={form.confirmNoLawyer} onChange={e => setForm(f => ({ ...f, confirmNoLawyer: e.target.checked }))} /><span>Ich habe noch keinen Anwalt oder Prozessfinanzierer mit der Rückforderung beauftragt und bin Inhaber meines Anspruches.</span></label>
                <label className={`form-checkbox ${form.confirmStopPlaying ? 'selected' : ''}`}><input type="checkbox" required checked={form.confirmStopPlaying} onChange={e => setForm(f => ({ ...f, confirmStopPlaying: e.target.checked }))} /><span>Ab sofort werde ich bei den verfahrensgegenständlichen Online Casinos nicht mehr spielen.</span></label>
                <label className={`form-checkbox ${form.confirmLegal ? 'selected' : ''}`}><input type="checkbox" required checked={form.confirmLegal} onChange={e => setForm(f => ({ ...f, confirmLegal: e.target.checked }))} /><span>Ich bestätige, dass ich die Vollmachten sowie den Vollfinanzierungsantrag gelesen und verstanden habe.</span></label>
              </div>
            </div>

            <div className="form-section">
              <div className="form-section-title">Dokumente hochladen</div>
              <FileUpload label="Ausweis" required onChange={files => setForm(f => ({ ...f, ausweisFiles: files }))} />
              <FileUpload label="Transaktionsdaten (optional)" onChange={files => setForm(f => ({ ...f, transaktionFiles: files }))} />
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
