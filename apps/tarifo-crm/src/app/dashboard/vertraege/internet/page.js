'use client';

import { useState, useEffect } from 'react';
import { getCurrentUser } from '@/lib/auth';
import { getContracts, saveContract, getCustomers } from '@/lib/store';

export default function InternetVertraegePage() {
  const [contracts, setContracts] = useState([]);
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState({
    customer_name: '', customer_id: '', anbieter: '', tarif: '', geschwindigkeit: '',
    kosten: '', laufzeit: '', adresse: '', kundennummer: '', notes: '',
  });

  useEffect(() => {
    setContracts(getContracts().filter((c) => c.type === 'internet'));
  }, []);

  const customers = getCustomers();

  const handleSave = () => {
    const user = getCurrentUser();
    saveContract({
      type: 'internet',
      customer_name: form.customer_name,
      customer_id: form.customer_id,
      provider: form.anbieter,
      contract_data: form,
      created_by: user?.id,
      status: 'pending',
    });
    setContracts(getContracts().filter((c) => c.type === 'internet'));
    setShowModal(false);
    setForm({ customer_name: '', customer_id: '', anbieter: '', tarif: '', geschwindigkeit: '', kosten: '', laufzeit: '', adresse: '', kundennummer: '', notes: '' });
  };

  return (
    <div>
      <div className="page-header">
        <div className="page-header-left">
          <h1>Internet & TV Verträge</h1>
          <p>Anträge werden lokal gespeichert und manuell eingespielt</p>
        </div>
        <div className="page-header-actions">
          <button className="btn btn-primary" onClick={() => setShowModal(true)}>+ Neuer Antrag</button>
        </div>
      </div>

      {contracts.length > 0 ? (
        <div className="table-container">
          <table className="table">
            <thead><tr><th>Kunde</th><th>Anbieter</th><th>Tarif</th><th>Speed</th><th>Kosten</th><th>Status</th><th>Datum</th></tr></thead>
            <tbody>
              {contracts.map((c) => (
                <tr key={c.id}>
                  <td style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{c.customer_name}</td>
                  <td>{c.provider}</td>
                  <td>{c.contract_data?.tarif || '-'}</td>
                  <td>{c.contract_data?.geschwindigkeit ? `${c.contract_data.geschwindigkeit} Mbps` : '-'}</td>
                  <td style={{ color: 'var(--accent-secondary)' }}>€{c.contract_data?.kosten || '-'}/Mo</td>
                  <td><span className={`badge-status ${c.status}`}>{c.status === 'pending' ? 'Ausstehend' : c.status === 'submitted' ? 'Eingereicht' : c.status}</span></td>
                  <td>{c.created_at ? new Date(c.created_at).toLocaleDateString('de-DE') : '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="card">
          <div className="empty-state">
            <div className="empty-state-icon">🌐</div>
            <h3>Keine Internet-Verträge</h3>
            <p>Erstellen Sie einen neuen Internet-Antrag</p>
            <button className="btn btn-primary" onClick={() => setShowModal(true)}>+ Neuer Antrag</button>
          </div>
        </div>
      )}

      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal modal-lg" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>🌐 Neuer Internet-Antrag</h3>
              <button className="modal-close" onClick={() => setShowModal(false)}>✕</button>
            </div>
            <div className="modal-body">
              <div className="form-row">
                <div className="form-group">
                  <label>Kunde *</label>
                  <select className="form-select" value={form.customer_id} onChange={(e) => {
                    const cust = customers.find((c) => c.id === e.target.value);
                    setForm({ ...form, customer_id: e.target.value, customer_name: cust?.name || '' });
                  }}>
                    <option value="">Kunde wählen</option>
                    {customers.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
                  </select>
                </div>
                <div className="form-group">
                  <label>Oder Name eingeben</label>
                  <input className="form-input" value={form.customer_name} onChange={(e) => setForm({ ...form, customer_name: e.target.value })} placeholder="Kundenname" />
                </div>
              </div>
              <div className="form-row">
                <div className="form-group">
                  <label>Anbieter *</label>
                  <select className="form-select" value={form.anbieter} onChange={(e) => setForm({ ...form, anbieter: e.target.value })}>
                    <option value="">Anbieter wählen</option>
                    <option value="A1">A1</option>
                    <option value="Magenta">Magenta</option>
                    <option value="Drei">Drei</option>
                    <option value="Fonira">Fonira</option>
                    <option value="kabelplus">kabelplus</option>
                    <option value="Sonstiger">Sonstiger</option>
                  </select>
                </div>
                <div className="form-group">
                  <label>Tarif/Produktname</label>
                  <input className="form-input" value={form.tarif} onChange={(e) => setForm({ ...form, tarif: e.target.value })} placeholder="z.B. Internet L" />
                </div>
              </div>
              <div className="form-row-3">
                <div className="form-group">
                  <label>Geschwindigkeit (Mbps)</label>
                  <input className="form-input" type="number" value={form.geschwindigkeit} onChange={(e) => setForm({ ...form, geschwindigkeit: e.target.value })} placeholder="100" />
                </div>
                <div className="form-group">
                  <label>Monatliche Kosten (€)</label>
                  <input className="form-input" type="number" value={form.kosten} onChange={(e) => setForm({ ...form, kosten: e.target.value })} placeholder="29.90" />
                </div>
                <div className="form-group">
                  <label>Vertragslaufzeit</label>
                  <select className="form-select" value={form.laufzeit} onChange={(e) => setForm({ ...form, laufzeit: e.target.value })}>
                    <option value="">Wählen</option>
                    <option value="12">12 Monate</option>
                    <option value="24">24 Monate</option>
                    <option value="0">Keine Bindung</option>
                  </select>
                </div>
              </div>
              <div className="form-group">
                <label>Adresse</label>
                <input className="form-input" value={form.adresse} onChange={(e) => setForm({ ...form, adresse: e.target.value })} placeholder="Installation-Adresse" />
              </div>
              <div className="form-group">
                <label>Anmerkungen</label>
                <textarea className="form-textarea" value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} placeholder="Weitere Details zum Antrag..." />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setShowModal(false)}>Abbrechen</button>
              <button className="btn btn-primary" onClick={handleSave} disabled={!form.customer_name || !form.anbieter}>Antrag speichern</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
