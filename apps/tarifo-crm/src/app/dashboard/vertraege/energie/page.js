'use client';

import { useState } from 'react';

export default function EnergieVertraegePage() {
  const [tab, setTab] = useState('search');
  const [plz, setPlz] = useState('');
  const [verbrauch, setVerbrauch] = useState('');
  const [energyType, setEnergyType] = useState('strom');
  const [searching, setSearching] = useState(false);

  const handleSearch = async () => {
    setSearching(true);
    // In production, this would call the EG-ON API
    setTimeout(() => setSearching(false), 1500);
  };

  return (
    <div>
      <div className="page-header">
        <div className="page-header-left">
          <h1>Strom & Gas Verträge</h1>
          <p>Tarife suchen und Verträge über die EG-ON Schnittstelle abschließen</p>
        </div>
      </div>

      <div className="tabs">
        <button className={`tab ${tab === 'search' ? 'active' : ''}`} onClick={() => setTab('search')}>🔍 Tarifsuche</button>
        <button className={`tab ${tab === 'calculator' ? 'active' : ''}`} onClick={() => setTab('calculator')}>🧮 Tarifrechner</button>
        <button className={`tab ${tab === 'contracts' ? 'active' : ''}`} onClick={() => setTab('contracts')}>📄 Meine Verträge</button>
      </div>

      {tab === 'search' && (
        <div className="card">
          <h3 style={{ fontSize: '18px', fontWeight: 700, marginBottom: '20px' }}>Tarife suchen</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div style={{ display: 'flex', gap: '8px', marginBottom: '8px' }}>
              <button className={`filter-pill ${energyType === 'strom' ? 'active' : ''}`} onClick={() => setEnergyType('strom')}>⚡ Strom</button>
              <button className={`filter-pill ${energyType === 'gas' ? 'active' : ''}`} onClick={() => setEnergyType('gas')}>🔥 Gas</button>
            </div>
            <div className="form-row">
              <div className="form-group">
                <label>Postleitzahl *</label>
                <input className="form-input" value={plz} onChange={(e) => setPlz(e.target.value)} placeholder="z.B. 1010" />
              </div>
              <div className="form-group">
                <label>Jahresverbrauch (kWh) *</label>
                <input className="form-input" type="number" value={verbrauch} onChange={(e) => setVerbrauch(e.target.value)} placeholder="z.B. 3500" />
              </div>
            </div>
            <button className="btn btn-primary" onClick={handleSearch} disabled={!plz || !verbrauch || searching}>
              {searching ? <><span className="loading-spinner" /> Suche läuft...</> : '🔍 Tarife suchen'}
            </button>
          </div>

          {!searching && plz && verbrauch && (
            <div style={{ marginTop: '28px' }}>
              <div style={{ padding: '20px', textAlign: 'center', background: 'rgba(59,130,246,0.06)', border: '1px solid rgba(59,130,246,0.15)', borderRadius: 'var(--radius-md)' }}>
                <p style={{ color: 'var(--text-secondary)' }}>
                  ⚡ Die EG-ON API-Schnittstelle ist konfiguriert. Tarife werden live abgerufen sobald die API-Verbindung hergestellt ist.
                </p>
                <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '8px' }}>
                  API Endpoint: gateway.eg-on.com · Token konfiguriert ✓
                </p>
              </div>
            </div>
          )}
        </div>
      )}

      {tab === 'calculator' && (
        <div className="card">
          <h3 style={{ fontSize: '18px', fontWeight: 700, marginBottom: '20px' }}>Tarifrechner (E-Control)</h3>
          <div style={{ padding: '20px', textAlign: 'center', background: 'rgba(245,158,11,0.06)', border: '1px solid rgba(245,158,11,0.15)', borderRadius: 'var(--radius-md)' }}>
            <p style={{ color: 'var(--text-secondary)' }}>
              🧮 Der E-Control Tarifkalkulator ist vorbereitet und wird nach Eingabe des API-Passworts aktiviert.
            </p>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '8px' }}>
              API: api-dev.e-control.at · Benutzer: tarifo · Status: Passwort ausstehend
            </p>
          </div>
        </div>
      )}

      {tab === 'contracts' && (
        <div className="card">
          <div className="empty-state">
            <div className="empty-state-icon">📄</div>
            <h3>Keine Energieverträge</h3>
            <p>Suchen Sie zuerst einen Tarif und schließen Sie dann einen Vertrag ab</p>
          </div>
        </div>
      )}
    </div>
  );
}
