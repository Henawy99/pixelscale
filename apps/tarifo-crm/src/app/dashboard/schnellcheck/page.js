'use client';

import { useState, useRef, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { getCurrentUser } from '@/lib/auth';
import { saveCustomer, saveSchnellcheck, getCustomers } from '@/lib/store';

const STEPS = [
  { label: 'Kundendaten', icon: '👤' },
  { label: 'Strom & Gas', icon: '⚡' },
  { label: 'Versicherung', icon: '🛡️' },
  { label: 'Finanzierung', icon: '🏦' },
  { label: 'Internet & TV', icon: '🌐' },
  { label: 'Auswertung', icon: '📊' },
];

const INSURANCE_TYPES = [
  'Haushaltsversicherung', 'KFZ-Versicherung', 'Unfallversicherung',
  'Lebensversicherung', 'Rechtsschutzversicherung', 'Krankenversicherung',
  'Haftpflichtversicherung', 'Berufsunfähigkeitsversicherung', 'Sonstige',
];

function SignaturePad({ onSave, label }) {
  const canvasRef = useRef(null);
  const [drawing, setDrawing] = useState(false);
  const [signed, setSigned] = useState(false);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    canvas.width = canvas.offsetWidth;
    canvas.height = 150;
    ctx.strokeStyle = '#3b82f6';
    ctx.lineWidth = 2;
    ctx.lineCap = 'round';
  }, []);

  const getPos = (e) => {
    const canvas = canvasRef.current;
    const rect = canvas.getBoundingClientRect();
    const clientX = e.touches ? e.touches[0].clientX : e.clientX;
    const clientY = e.touches ? e.touches[0].clientY : e.clientY;
    return { x: clientX - rect.left, y: clientY - rect.top };
  };

  const startDraw = (e) => {
    e.preventDefault();
    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    const pos = getPos(e);
    ctx.beginPath();
    ctx.moveTo(pos.x, pos.y);
    setDrawing(true);
  };

  const draw = (e) => {
    e.preventDefault();
    if (!drawing) return;
    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    const pos = getPos(e);
    ctx.lineTo(pos.x, pos.y);
    ctx.stroke();
    setSigned(true);
  };

  const stopDraw = () => {
    setDrawing(false);
    if (signed) {
      const canvas = canvasRef.current;
      onSave(canvas.toDataURL());
    }
  };

  const clear = () => {
    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    setSigned(false);
    onSave('');
  };

  return (
    <div className="signature-pad-container">
      <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: '8px', display: 'block' }}>
        {label}
      </label>
      <canvas
        ref={canvasRef}
        className="signature-pad"
        onMouseDown={startDraw}
        onMouseMove={draw}
        onMouseUp={stopDraw}
        onMouseLeave={stopDraw}
        onTouchStart={startDraw}
        onTouchMove={draw}
        onTouchEnd={stopDraw}
      />
      <div className="signature-pad-actions">
        <button type="button" className="btn btn-ghost btn-sm" onClick={clear}>
          Löschen
        </button>
        {signed && <span style={{ color: 'var(--accent-secondary)', fontSize: '12px' }}>✓ Unterschrieben</span>}
      </div>
    </div>
  );
}

export default function SchnellcheckPage() {
  const [step, setStep] = useState(0);
  const [user, setUser] = useState(null);
  const [saved, setSaved] = useState(false);
  const router = useRouter();

  // Form data
  const [customerData, setCustomerData] = useState({ name: '', email: '', phone: '' });
  const [stromGasData, setStromGasData] = useState({
    strom_anbieter: '', strom_letzter_wechsel: '', strom_verbrauch: '', strom_personen: '',
    strom_plz: '', strom_kosten: '',
    gas_anbieter: '', gas_letzter_wechsel: '', gas_verbrauch: '', gas_personen: '',
    gas_plz: '', gas_kosten: '',
  });
  const [versicherungData, setVersicherungData] = useState({
    existing_contracts: [],
    preference: '', notes: '',
    consent_signature: '', privacy_signature: '',
  });
  const [finanzierungData, setFinanzierungData] = useState({
    existing_credits: [], credit_wishes: '',
  });
  const [internetData, setInternetData] = useState({
    anbieter: '', vertrag_datum: '', geschwindigkeit: '', kosten: '',
  });

  // Insurance contract temp
  const [newInsurance, setNewInsurance] = useState({ type: '', anbieter: '', kosten: '' });
  // Credit temp
  const [newCredit, setNewCredit] = useState({ type: '', betrag: '', rate: '', laufzeit: '' });

  useEffect(() => {
    const currentUser = getCurrentUser();
    if (currentUser) setUser(currentUser);
  }, []);

  const addInsuranceContract = () => {
    if (!newInsurance.type) return;
    setVersicherungData((prev) => ({
      ...prev,
      existing_contracts: [...prev.existing_contracts, { ...newInsurance, id: Date.now() }],
    }));
    setNewInsurance({ type: '', anbieter: '', kosten: '' });
  };

  const removeInsurance = (id) => {
    setVersicherungData((prev) => ({
      ...prev,
      existing_contracts: prev.existing_contracts.filter((c) => c.id !== id),
    }));
  };

  const addCredit = () => {
    if (!newCredit.type) return;
    setFinanzierungData((prev) => ({
      ...prev,
      existing_credits: [...prev.existing_credits, { ...newCredit, id: Date.now() }],
    }));
    setNewCredit({ type: '', betrag: '', rate: '', laufzeit: '' });
  };

  const removeCredit = (id) => {
    setFinanzierungData((prev) => ({
      ...prev,
      existing_credits: prev.existing_credits.filter((c) => c.id !== id),
    }));
  };

  const handleSave = () => {
    // Save customer
    const customer = saveCustomer({
      ...customerData,
      postal_code: stromGasData.strom_plz || internetData.plz,
      created_by: user?.id,
    });

    // Save schnellcheck
    saveSchnellcheck({
      customer_id: customer.id,
      customer_name: customerData.name,
      created_by: user?.id,
      status: 'completed',
      strom_gas_data: stromGasData,
      versicherung_data: versicherungData,
      finanzierung_data: finanzierungData,
      internet_tv_data: internetData,
    });

    setSaved(true);
  };

  const nextStep = () => setStep((s) => Math.min(s + 1, STEPS.length - 1));
  const prevStep = () => setStep((s) => Math.max(s - 1, 0));

  // Estimated savings calculation
  const estimatedSavings = () => {
    const stromKosten = parseFloat(stromGasData.strom_kosten) || 0;
    const gasKosten = parseFloat(stromGasData.gas_kosten) || 0;
    const internetKosten = parseFloat(internetData.kosten) || 0;
    const totalMonthly = stromKosten + gasKosten + internetKosten;
    const estimatedSaving = totalMonthly * 0.15; // 15% estimated savings
    return { totalMonthly, estimatedSaving, yearlyTotal: totalMonthly * 12, yearlySaving: estimatedSaving * 12 };
  };

  return (
    <div>
      <div className="page-header">
        <div className="page-header-left">
          <h1>Schnellcheck</h1>
          <p>Kundenbedarf ermitteln und Einsparpotenzial berechnen</p>
        </div>
      </div>

      {/* Wizard Steps */}
      <div className="wizard-steps">
        {STEPS.map((s, i) => (
          <div key={i} style={{ display: 'contents' }}>
            <div
              className={`wizard-step ${i === step ? 'active' : ''} ${i < step ? 'completed' : ''}`}
              onClick={() => i <= step && setStep(i)}
              style={{ cursor: i <= step ? 'pointer' : 'default' }}
            >
              <div className="wizard-step-circle">
                {i < step ? '✓' : s.icon}
              </div>
              <span className="wizard-step-label">{s.label}</span>
            </div>
            {i < STEPS.length - 1 && (
              <div className={`wizard-connector ${i < step ? 'completed' : ''}`} />
            )}
          </div>
        ))}
      </div>

      {/* Step Content */}
      <div className="card">
        <div className="wizard-content">
          {/* Step 1: Customer Data */}
          {step === 0 && (
            <div>
              <h3 style={{ fontSize: '18px', fontWeight: 700, marginBottom: '20px' }}>
                👤 Kundendaten
              </h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <div className="form-group">
                  <label>Name *</label>
                  <input
                    className="form-input"
                    placeholder="Vor- und Nachname"
                    value={customerData.name}
                    onChange={(e) => setCustomerData({ ...customerData, name: e.target.value })}
                  />
                </div>
                <div className="form-row">
                  <div className="form-group">
                    <label>E-Mail *</label>
                    <input
                      className="form-input"
                      type="email"
                      placeholder="email@beispiel.at"
                      value={customerData.email}
                      onChange={(e) => setCustomerData({ ...customerData, email: e.target.value })}
                    />
                  </div>
                  <div className="form-group">
                    <label>Telefonnummer *</label>
                    <input
                      className="form-input"
                      type="tel"
                      placeholder="+43 664 ..."
                      value={customerData.phone}
                      onChange={(e) => setCustomerData({ ...customerData, phone: e.target.value })}
                    />
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Step 2: Strom & Gas */}
          {step === 1 && (
            <div>
              <h3 style={{ fontSize: '18px', fontWeight: 700, marginBottom: '20px' }}>
                ⚡ Strom & Gas
              </h3>

              {/* Strom */}
              <h4 style={{ fontSize: '15px', fontWeight: 600, marginBottom: '14px', color: 'var(--accent-primary)' }}>
                🔌 Strom
              </h4>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '14px', marginBottom: '28px' }}>
                <div className="form-row">
                  <div className="form-group">
                    <label>Aktueller Anbieter</label>
                    <input className="form-input" placeholder="z.B. Wien Energie"
                      value={stromGasData.strom_anbieter}
                      onChange={(e) => setStromGasData({ ...stromGasData, strom_anbieter: e.target.value })} />
                  </div>
                  <div className="form-group">
                    <label>Letzter Wechsel</label>
                    <select className="form-select" value={stromGasData.strom_letzter_wechsel}
                      onChange={(e) => setStromGasData({ ...stromGasData, strom_letzter_wechsel: e.target.value })}>
                      <option value="">Bitte wählen</option>
                      <option value="unter_1_jahr">Unter 1 Jahr</option>
                      <option value="ueber_1_jahr">Über 1 Jahr</option>
                      <option value="noch_nie">Noch nie gewechselt</option>
                    </select>
                  </div>
                </div>
                <div className="form-row">
                  <div className="form-group">
                    <label>Jahresverbrauch (kWh)</label>
                    <input className="form-input" type="number" placeholder="z.B. 3500"
                      value={stromGasData.strom_verbrauch}
                      onChange={(e) => setStromGasData({ ...stromGasData, strom_verbrauch: e.target.value })} />
                  </div>
                  <div className="form-group">
                    <label>Personen im Haushalt</label>
                    <select className="form-select" value={stromGasData.strom_personen}
                      onChange={(e) => setStromGasData({ ...stromGasData, strom_personen: e.target.value })}>
                      <option value="">Falls Verbrauch unbekannt</option>
                      <option value="1">1 Person (~1.500 kWh)</option>
                      <option value="2">2 Personen (~2.500 kWh)</option>
                      <option value="3">3 Personen (~3.500 kWh)</option>
                      <option value="4">4 Personen (~4.500 kWh)</option>
                      <option value="5">5+ Personen (~5.500 kWh)</option>
                    </select>
                  </div>
                </div>
                <div className="form-row">
                  <div className="form-group">
                    <label>Postleitzahl</label>
                    <input className="form-input" placeholder="z.B. 1010"
                      value={stromGasData.strom_plz}
                      onChange={(e) => setStromGasData({ ...stromGasData, strom_plz: e.target.value })} />
                  </div>
                  <div className="form-group">
                    <label>Kosten pro Monat (€)</label>
                    <input className="form-input" type="number" placeholder="z.B. 85"
                      value={stromGasData.strom_kosten}
                      onChange={(e) => setStromGasData({ ...stromGasData, strom_kosten: e.target.value })} />
                  </div>
                </div>
              </div>

              {/* Gas */}
              <h4 style={{ fontSize: '15px', fontWeight: 600, marginBottom: '14px', color: 'var(--accent-warning)' }}>
                🔥 Gas
              </h4>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div className="form-row">
                  <div className="form-group">
                    <label>Aktueller Anbieter</label>
                    <input className="form-input" placeholder="z.B. Wien Energie"
                      value={stromGasData.gas_anbieter}
                      onChange={(e) => setStromGasData({ ...stromGasData, gas_anbieter: e.target.value })} />
                  </div>
                  <div className="form-group">
                    <label>Letzter Wechsel</label>
                    <select className="form-select" value={stromGasData.gas_letzter_wechsel}
                      onChange={(e) => setStromGasData({ ...stromGasData, gas_letzter_wechsel: e.target.value })}>
                      <option value="">Bitte wählen</option>
                      <option value="unter_1_jahr">Unter 1 Jahr</option>
                      <option value="ueber_1_jahr">Über 1 Jahr</option>
                      <option value="noch_nie">Noch nie gewechselt</option>
                    </select>
                  </div>
                </div>
                <div className="form-row">
                  <div className="form-group">
                    <label>Jahresverbrauch (kWh)</label>
                    <input className="form-input" type="number" placeholder="z.B. 15000"
                      value={stromGasData.gas_verbrauch}
                      onChange={(e) => setStromGasData({ ...stromGasData, gas_verbrauch: e.target.value })} />
                  </div>
                  <div className="form-group">
                    <label>Kosten pro Monat (€)</label>
                    <input className="form-input" type="number" placeholder="z.B. 120"
                      value={stromGasData.gas_kosten}
                      onChange={(e) => setStromGasData({ ...stromGasData, gas_kosten: e.target.value })} />
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Step 3: Versicherung */}
          {step === 2 && (
            <div>
              <h3 style={{ fontSize: '18px', fontWeight: 700, marginBottom: '20px' }}>
                🛡️ Versicherungen
              </h3>

              <h4 style={{ fontSize: '14px', fontWeight: 600, marginBottom: '12px' }}>Bestehende Verträge</h4>
              {versicherungData.existing_contracts.map((c) => (
                <div key={c.id} style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                  padding: '12px 16px', background: 'var(--bg-elevated)', borderRadius: 'var(--radius-md)',
                  marginBottom: '8px',
                }}>
                  <div>
                    <span style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{c.type}</span>
                    <span style={{ color: 'var(--text-muted)', marginLeft: '12px' }}>{c.anbieter}</span>
                    {c.kosten && <span style={{ color: 'var(--accent-secondary)', marginLeft: '12px' }}>€{c.kosten}/Mo</span>}
                  </div>
                  <button className="btn btn-ghost btn-sm" onClick={() => removeInsurance(c.id)}>✕</button>
                </div>
              ))}

              <div className="form-row-3" style={{ marginBottom: '12px' }}>
                <div className="form-group">
                  <label>Versicherungsart</label>
                  <select className="form-select" value={newInsurance.type}
                    onChange={(e) => setNewInsurance({ ...newInsurance, type: e.target.value })}>
                    <option value="">Auswählen</option>
                    {INSURANCE_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
                  </select>
                </div>
                <div className="form-group">
                  <label>Anbieter</label>
                  <input className="form-input" placeholder="Versicherer"
                    value={newInsurance.anbieter}
                    onChange={(e) => setNewInsurance({ ...newInsurance, anbieter: e.target.value })} />
                </div>
                <div className="form-group">
                  <label>Kosten/Monat</label>
                  <div style={{ display: 'flex', gap: 8 }}>
                    <input className="form-input" type="number" placeholder="€"
                      value={newInsurance.kosten}
                      onChange={(e) => setNewInsurance({ ...newInsurance, kosten: e.target.value })} />
                    <button className="btn btn-primary btn-sm" onClick={addInsuranceContract}>+</button>
                  </div>
                </div>
              </div>

              <div className="divider" />

              <div className="form-group" style={{ marginBottom: '16px' }}>
                <label>Wunsch des Kunden</label>
                <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                  {['Günstigere Angebote bei gleicher Leistung', 'Bessere Leistung bei gleichem Preis'].map((opt) => (
                    <button key={opt} type="button"
                      className={`filter-pill ${versicherungData.preference === opt ? 'active' : ''}`}
                      onClick={() => setVersicherungData({ ...versicherungData, preference: opt })}>
                      {opt}
                    </button>
                  ))}
                </div>
              </div>

              <div className="form-group" style={{ marginBottom: '20px' }}>
                <label>Sonstige Wünsche / Notizen</label>
                <textarea className="form-textarea" placeholder="z.B. Kunde will eine Haushaltsversicherung"
                  value={versicherungData.notes}
                  onChange={(e) => setVersicherungData({ ...versicherungData, notes: e.target.value })} />
              </div>

              <div className="divider" />

              <SignaturePad
                label="Einverständniserklärung unterschreiben"
                onSave={(sig) => setVersicherungData({ ...versicherungData, consent_signature: sig })}
              />
              <div style={{ height: '20px' }} />
              <SignaturePad
                label="Datenschutzerklärung unterschreiben"
                onSave={(sig) => setVersicherungData({ ...versicherungData, privacy_signature: sig })}
              />
            </div>
          )}

          {/* Step 4: Finanzierung */}
          {step === 3 && (
            <div>
              <h3 style={{ fontSize: '18px', fontWeight: 700, marginBottom: '20px' }}>
                🏦 Finanzierung
              </h3>

              <h4 style={{ fontSize: '14px', fontWeight: 600, marginBottom: '12px' }}>Bestehende Kredite</h4>
              {finanzierungData.existing_credits.map((c) => (
                <div key={c.id} style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                  padding: '12px 16px', background: 'var(--bg-elevated)', borderRadius: 'var(--radius-md)',
                  marginBottom: '8px',
                }}>
                  <div>
                    <span style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{c.type}</span>
                    <span style={{ color: 'var(--accent-primary)', marginLeft: '12px' }}>€{c.betrag}</span>
                    <span style={{ color: 'var(--text-muted)', marginLeft: '12px' }}>€{c.rate}/Mo</span>
                    <span style={{ color: 'var(--text-muted)', marginLeft: '12px' }}>{c.laufzeit} Monate</span>
                  </div>
                  <button className="btn btn-ghost btn-sm" onClick={() => removeCredit(c.id)}>✕</button>
                </div>
              ))}

              <div className="form-row" style={{ marginBottom: '8px' }}>
                <div className="form-group">
                  <label>Art des Kredits</label>
                  <input className="form-input" placeholder="z.B. Autokredit"
                    value={newCredit.type}
                    onChange={(e) => setNewCredit({ ...newCredit, type: e.target.value })} />
                </div>
                <div className="form-group">
                  <label>Kreditbetrag (€)</label>
                  <input className="form-input" type="number" placeholder="z.B. 25000"
                    value={newCredit.betrag}
                    onChange={(e) => setNewCredit({ ...newCredit, betrag: e.target.value })} />
                </div>
              </div>
              <div className="form-row" style={{ marginBottom: '12px' }}>
                <div className="form-group">
                  <label>Monatliche Rate (€)</label>
                  <input className="form-input" type="number" placeholder="z.B. 350"
                    value={newCredit.rate}
                    onChange={(e) => setNewCredit({ ...newCredit, rate: e.target.value })} />
                </div>
                <div className="form-group">
                  <label>Restlaufzeit (Monate)</label>
                  <div style={{ display: 'flex', gap: 8 }}>
                    <input className="form-input" type="number" placeholder="z.B. 48"
                      value={newCredit.laufzeit}
                      onChange={(e) => setNewCredit({ ...newCredit, laufzeit: e.target.value })} />
                    <button className="btn btn-primary btn-sm" onClick={addCredit}>+</button>
                  </div>
                </div>
              </div>

              <div className="divider" />

              <div className="form-group">
                <label>Sonstige Kreditwünsche</label>
                <textarea className="form-textarea"
                  placeholder="z.B. Kunde plant Hauskauf, braucht eine Finanzierung über €300.000"
                  value={finanzierungData.credit_wishes}
                  onChange={(e) => setFinanzierungData({ ...finanzierungData, credit_wishes: e.target.value })} />
              </div>
            </div>
          )}

          {/* Step 5: Internet & TV */}
          {step === 4 && (
            <div>
              <h3 style={{ fontSize: '18px', fontWeight: 700, marginBottom: '20px' }}>
                🌐 Internet & TV
              </h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div className="form-row">
                  <div className="form-group">
                    <label>Aktueller Anbieter</label>
                    <input className="form-input" placeholder="z.B. A1, Magenta, Drei"
                      value={internetData.anbieter}
                      onChange={(e) => setInternetData({ ...internetData, anbieter: e.target.value })} />
                  </div>
                  <div className="form-group">
                    <label>Vertrag abgeschlossen am</label>
                    <input className="form-input" type="date"
                      value={internetData.vertrag_datum}
                      onChange={(e) => setInternetData({ ...internetData, vertrag_datum: e.target.value })} />
                  </div>
                </div>
                <div className="form-row">
                  <div className="form-group">
                    <label>Geschwindigkeit (Mbps)</label>
                    <input className="form-input" type="number" placeholder="z.B. 100"
                      value={internetData.geschwindigkeit}
                      onChange={(e) => setInternetData({ ...internetData, geschwindigkeit: e.target.value })} />
                  </div>
                  <div className="form-group">
                    <label>Kosten pro Monat (€)</label>
                    <input className="form-input" type="number" placeholder="z.B. 35"
                      value={internetData.kosten}
                      onChange={(e) => setInternetData({ ...internetData, kosten: e.target.value })} />
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Step 6: Auswertung */}
          {step === 5 && (
            <div>
              <h3 style={{ fontSize: '18px', fontWeight: 700, marginBottom: '24px' }}>
                📊 Auswertung & Empfehlung
              </h3>

              {saved ? (
                <div style={{ textAlign: 'center', padding: '40px 20px' }}>
                  <div style={{ fontSize: '64px', marginBottom: '16px' }}>✅</div>
                  <h3 style={{ fontSize: '22px', fontWeight: 700, marginBottom: '8px' }}>Schnellcheck gespeichert!</h3>
                  <p style={{ color: 'var(--text-secondary)', marginBottom: '24px' }}>
                    Der Schnellcheck für {customerData.name} wurde erfolgreich gespeichert.
                  </p>
                  <div style={{ display: 'flex', gap: '12px', justifyContent: 'center' }}>
                    <button className="btn btn-primary" onClick={() => router.push('/dashboard')}>
                      Zum Dashboard
                    </button>
                    <button className="btn btn-secondary" onClick={() => {
                      setStep(0);
                      setCustomerData({ name: '', email: '', phone: '' });
                      setStromGasData({ strom_anbieter: '', strom_letzter_wechsel: '', strom_verbrauch: '', strom_personen: '', strom_plz: '', strom_kosten: '', gas_anbieter: '', gas_letzter_wechsel: '', gas_verbrauch: '', gas_personen: '', gas_plz: '', gas_kosten: '' });
                      setVersicherungData({ existing_contracts: [], preference: '', notes: '', consent_signature: '', privacy_signature: '' });
                      setFinanzierungData({ existing_credits: [], credit_wishes: '' });
                      setInternetData({ anbieter: '', vertrag_datum: '', geschwindigkeit: '', kosten: '' });
                      setSaved(false);
                    }}>
                      Neuer Schnellcheck
                    </button>
                  </div>
                </div>
              ) : (
                <>
                  {/* Customer Summary */}
                  <div style={{ padding: '16px', background: 'var(--bg-elevated)', borderRadius: 'var(--radius-md)', marginBottom: '20px' }}>
                    <h4 style={{ fontSize: '14px', fontWeight: 600, marginBottom: '8px', color: 'var(--accent-primary)' }}>Kunde</h4>
                    <p><strong>{customerData.name}</strong> · {customerData.email} · {customerData.phone}</p>
                  </div>

                  {/* Savings Estimate */}
                  {(stromGasData.strom_kosten || stromGasData.gas_kosten || internetData.kosten) && (
                    <div style={{
                      padding: '24px', background: 'linear-gradient(135deg, rgba(16,185,129,0.1), rgba(59,130,246,0.1))',
                      border: '1px solid rgba(16,185,129,0.2)', borderRadius: 'var(--radius-lg)', marginBottom: '20px',
                    }}>
                      <h4 style={{ fontSize: '16px', fontWeight: 700, marginBottom: '16px' }}>💰 Geschätztes Einsparpotenzial</h4>
                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: '16px' }}>
                        <div>
                          <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Aktuelle Kosten/Monat</div>
                          <div style={{ fontSize: '24px', fontWeight: 800 }}>€{estimatedSavings().totalMonthly.toFixed(0)}</div>
                        </div>
                        <div>
                          <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Geschätzte Ersparnis/Monat</div>
                          <div style={{ fontSize: '24px', fontWeight: 800, color: 'var(--accent-secondary)' }}>€{estimatedSavings().estimatedSaving.toFixed(0)}</div>
                        </div>
                        <div>
                          <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Jährliche Ersparnis</div>
                          <div style={{ fontSize: '24px', fontWeight: 800, color: 'var(--accent-secondary)' }}>€{estimatedSavings().yearlySaving.toFixed(0)}</div>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* Section Summaries */}
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginBottom: '20px' }}>
                    {stromGasData.strom_anbieter && (
                      <div style={{ padding: '16px', background: 'var(--bg-elevated)', borderRadius: 'var(--radius-md)', borderLeft: '3px solid var(--accent-primary)' }}>
                        <h4 style={{ fontSize: '14px', fontWeight: 600, marginBottom: '6px' }}>⚡ Strom</h4>
                        <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
                          Anbieter: {stromGasData.strom_anbieter} · PLZ: {stromGasData.strom_plz} · 
                          {stromGasData.strom_verbrauch ? ` ${stromGasData.strom_verbrauch} kWh/Jahr` : ` ${stromGasData.strom_personen} Personen`} · 
                          €{stromGasData.strom_kosten}/Mo
                        </p>
                        <p style={{ fontSize: '12px', color: 'var(--accent-secondary)', marginTop: '4px' }}>
                          → Tarifvergleich empfohlen. Wechselpotenzial prüfen.
                        </p>
                      </div>
                    )}
                    {stromGasData.gas_anbieter && (
                      <div style={{ padding: '16px', background: 'var(--bg-elevated)', borderRadius: 'var(--radius-md)', borderLeft: '3px solid var(--accent-warning)' }}>
                        <h4 style={{ fontSize: '14px', fontWeight: 600, marginBottom: '6px' }}>🔥 Gas</h4>
                        <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
                          Anbieter: {stromGasData.gas_anbieter} · {stromGasData.gas_verbrauch ? `${stromGasData.gas_verbrauch} kWh/Jahr` : ''} · €{stromGasData.gas_kosten}/Mo
                        </p>
                        <p style={{ fontSize: '12px', color: 'var(--accent-secondary)', marginTop: '4px' }}>
                          → Tarifvergleich empfohlen. Wechselpotenzial prüfen.
                        </p>
                      </div>
                    )}
                    {versicherungData.existing_contracts.length > 0 && (
                      <div style={{ padding: '16px', background: 'var(--bg-elevated)', borderRadius: 'var(--radius-md)', borderLeft: '3px solid var(--accent-purple)' }}>
                        <h4 style={{ fontSize: '14px', fontWeight: 600, marginBottom: '6px' }}>🛡️ Versicherungen</h4>
                        <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
                          {versicherungData.existing_contracts.length} Verträge erfasst · Wunsch: {versicherungData.preference || 'Nicht angegeben'}
                        </p>
                        <p style={{ fontSize: '12px', color: 'var(--accent-warning)', marginTop: '4px' }}>
                          → Daten werden an Versicherungspartner weitergeleitet
                        </p>
                      </div>
                    )}
                    {(finanzierungData.existing_credits.length > 0 || finanzierungData.credit_wishes) && (
                      <div style={{ padding: '16px', background: 'var(--bg-elevated)', borderRadius: 'var(--radius-md)', borderLeft: '3px solid var(--accent-pink)' }}>
                        <h4 style={{ fontSize: '14px', fontWeight: 600, marginBottom: '6px' }}>🏦 Finanzierung</h4>
                        <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
                          {finanzierungData.existing_credits.length} Kredite erfasst
                          {finanzierungData.credit_wishes && ` · Wünsche: ${finanzierungData.credit_wishes}`}
                        </p>
                        <p style={{ fontSize: '12px', color: 'var(--accent-warning)', marginTop: '4px' }}>
                          → Anfrage wird an Finanzierungspartner weitergeleitet
                        </p>
                      </div>
                    )}
                    {internetData.anbieter && (
                      <div style={{ padding: '16px', background: 'var(--bg-elevated)', borderRadius: 'var(--radius-md)', borderLeft: '3px solid var(--accent-secondary)' }}>
                        <h4 style={{ fontSize: '14px', fontWeight: 600, marginBottom: '6px' }}>🌐 Internet & TV</h4>
                        <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
                          Anbieter: {internetData.anbieter} · {internetData.geschwindigkeit} Mbps · €{internetData.kosten}/Mo
                        </p>
                        <p style={{ fontSize: '12px', color: 'var(--accent-secondary)', marginTop: '4px' }}>
                          → Alternativangebote prüfen
                        </p>
                      </div>
                    )}
                  </div>

                  <button className="btn btn-success btn-lg btn-full" onClick={handleSave}>
                    ✓ Schnellcheck speichern
                  </button>
                </>
              )}
            </div>
          )}
        </div>

        {/* Navigation */}
        {step < 5 || !saved ? (
          <div className="wizard-actions">
            <button className="btn btn-secondary" onClick={prevStep} disabled={step === 0}>
              ← Zurück
            </button>
            {step < 5 && (
              <button className="btn btn-primary" onClick={nextStep}>
                Weiter →
              </button>
            )}
          </div>
        ) : null}
      </div>
    </div>
  );
}
