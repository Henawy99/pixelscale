'use client';

import { useState, useEffect } from 'react';
import { getCurrentUser } from '@/lib/auth';
import { getCustomers, saveCustomer, deleteCustomer } from '@/lib/store';

export default function KundenPage() {
  const [customers, setCustomers] = useState([]);
  const [showModal, setShowModal] = useState(false);
  const [search, setSearch] = useState('');
  const [form, setForm] = useState({ name: '', email: '', phone: '', address: '', postal_code: '' });
  const [editId, setEditId] = useState(null);

  useEffect(() => {
    setCustomers(getCustomers());
  }, []);

  const filtered = customers.filter((c) =>
    c.name?.toLowerCase().includes(search.toLowerCase()) ||
    c.email?.toLowerCase().includes(search.toLowerCase()) ||
    c.phone?.includes(search)
  );

  const handleSave = () => {
    const user = getCurrentUser();
    const saved = saveCustomer({ ...form, id: editId, created_by: user?.id });
    setCustomers(getCustomers());
    setShowModal(false);
    setForm({ name: '', email: '', phone: '', address: '', postal_code: '' });
    setEditId(null);
  };

  const handleEdit = (customer) => {
    setForm(customer);
    setEditId(customer.id);
    setShowModal(true);
  };

  const handleDelete = (id) => {
    if (confirm('Kunden wirklich löschen?')) {
      deleteCustomer(id);
      setCustomers(getCustomers());
    }
  };

  return (
    <div>
      <div className="page-header">
        <div className="page-header-left">
          <h1>Kunden</h1>
          <p>{customers.length} Kunden gesamt</p>
        </div>
        <div className="page-header-actions">
          <div className="search-bar">
            <span className="icon">🔍</span>
            <input placeholder="Kunden suchen..." value={search} onChange={(e) => setSearch(e.target.value)} />
          </div>
          <button className="btn btn-primary" onClick={() => { setShowModal(true); setEditId(null); setForm({ name: '', email: '', phone: '', address: '', postal_code: '' }); }}>
            + Neuer Kunde
          </button>
        </div>
      </div>

      {filtered.length > 0 ? (
        <div className="table-container">
          <table className="table">
            <thead>
              <tr>
                <th>Name</th>
                <th>E-Mail</th>
                <th>Telefon</th>
                <th>PLZ</th>
                <th>Erstellt</th>
                <th>Aktionen</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((c) => (
                <tr key={c.id}>
                  <td style={{ color: 'var(--text-primary)', fontWeight: 600 }}>{c.name}</td>
                  <td>{c.email}</td>
                  <td>{c.phone}</td>
                  <td>{c.postal_code}</td>
                  <td>{c.created_at ? new Date(c.created_at).toLocaleDateString('de-DE') : '-'}</td>
                  <td>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button className="btn btn-ghost btn-sm" onClick={() => handleEdit(c)}>✏️</button>
                      <button className="btn btn-ghost btn-sm" onClick={() => handleDelete(c.id)}>🗑️</button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="card">
          <div className="empty-state">
            <div className="empty-state-icon">👥</div>
            <h3>Keine Kunden</h3>
            <p>Erstellen Sie Ihren ersten Kunden oder führen Sie einen Schnellcheck durch</p>
            <button className="btn btn-primary" onClick={() => setShowModal(true)}>+ Neuer Kunde</button>
          </div>
        </div>
      )}

      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>{editId ? 'Kunde bearbeiten' : 'Neuer Kunde'}</h3>
              <button className="modal-close" onClick={() => setShowModal(false)}>✕</button>
            </div>
            <div className="modal-body">
              <div className="form-group">
                <label>Name *</label>
                <input className="form-input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="Vor- und Nachname" />
              </div>
              <div className="form-row">
                <div className="form-group">
                  <label>E-Mail</label>
                  <input className="form-input" type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} placeholder="email@beispiel.at" />
                </div>
                <div className="form-group">
                  <label>Telefon</label>
                  <input className="form-input" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} placeholder="+43 ..." />
                </div>
              </div>
              <div className="form-row">
                <div className="form-group">
                  <label>Adresse</label>
                  <input className="form-input" value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} placeholder="Straße, Hausnr" />
                </div>
                <div className="form-group">
                  <label>PLZ</label>
                  <input className="form-input" value={form.postal_code} onChange={(e) => setForm({ ...form, postal_code: e.target.value })} placeholder="z.B. 1010" />
                </div>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setShowModal(false)}>Abbrechen</button>
              <button className="btn btn-primary" onClick={handleSave} disabled={!form.name}>Speichern</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
