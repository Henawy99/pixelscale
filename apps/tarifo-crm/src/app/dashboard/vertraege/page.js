'use client';

import { useState, useEffect } from 'react';
import { getCurrentUser } from '@/lib/auth';
import { getContracts, saveContract, getCustomers } from '@/lib/store';

const CONTRACT_TYPES = {
  strom: { label: 'Strom', icon: '🔌', color: 'blue' },
  gas: { label: 'Gas', icon: '🔥', color: 'amber' },
  internet: { label: 'Internet & TV', icon: '🌐', color: 'green' },
  versicherung: { label: 'Versicherung', icon: '🛡️', color: 'purple' },
  finanzierung: { label: 'Finanzierung', icon: '🏦', color: 'purple' },
};

const STATUS_LABELS = {
  pending: 'Ausstehend', submitted: 'Eingereicht', active: 'Aktiv',
  rejected: 'Abgelehnt', cancelled: 'Storniert',
};

export default function VertraegePage() {
  const [contracts, setContracts] = useState([]);
  const [showModal, setShowModal] = useState(false);
  const [filterType, setFilterType] = useState('all');
  const [filterStatus, setFilterStatus] = useState('all');
  const [form, setForm] = useState({ type: 'strom', provider: '', customer_name: '', customer_id: '', status: 'pending', commission_amount: '', notes: '' });

  useEffect(() => {
    setContracts(getContracts());
  }, []);

  const customers = getCustomers();

  const filtered = contracts.filter((c) => {
    const matchType = filterType === 'all' || c.type === filterType;
    const matchStatus = filterStatus === 'all' || c.status === filterStatus;
    return matchType && matchStatus;
  });

  const handleSave = () => {
    const user = getCurrentUser();
    saveContract({ ...form, created_by: user?.id, commission_amount: parseFloat(form.commission_amount) || 0 });
    setContracts(getContracts());
    setShowModal(false);
    setForm({ type: 'strom', provider: '', customer_name: '', customer_id: '', status: 'pending', commission_amount: '', notes: '' });
  };

  const handleStatusChange = (contractId, newStatus) => {
    const contract = contracts.find((c) => c.id === contractId);
    if (contract) {
      saveContract({ ...contract, status: newStatus });
      setContracts(getContracts());
    }
  };

  return (
    <div>
      <div className="page-header">
        <div className="page-header-left">
          <h1>Verträge</h1>
          <p>{contracts.length} Verträge gesamt · {contracts.filter((c) => c.status === 'active').length} aktiv</p>
        </div>
        <div className="page-header-actions">
          <button className="btn btn-primary" onClick={() => setShowModal(true)}>
            + Neuer Vertrag
          </button>
        </div>
      </div>

      {/* Stat Cards */}
      <div className="stats-grid" style={{ marginBottom: '24px' }}>
        {Object.entries(CONTRACT_TYPES).map(([key, type]) => {
          const count = contracts.filter((c) => c.type === key).length;
          return (
            <div key={key} className={`stat-card ${type.color} fade-in`} onClick={() => setFilterType(key === filterType ? 'all' : key)} style={{ cursor: 'pointer' }}>
              <div className="stat-card-header">
                <span className="stat-card-label">{type.label}</span>
                <div className={`stat-card-icon ${type.color}`}>{type.icon}</div>
              </div>
              <div className="stat-card-value">{count}</div>
            </div>
          );
        })}
      </div>

      {/* Filters */}
      <div className="filter-bar">
        <div className="filter-pills">
          <button className={`filter-pill ${filterType === 'all' ? 'active' : ''}`} onClick={() => setFilterType('all')}>Alle</button>
          {Object.entries(CONTRACT_TYPES).map(([key, type]) => (
            <button key={key} className={`filter-pill ${filterType === key ? 'active' : ''}`} onClick={() => setFilterType(key)}>
              {type.icon} {type.label}
            </button>
          ))}
        </div>
      </div>

      {/* Contracts Table */}
      {filtered.length > 0 ? (
        <div className="table-container">
          <table className="table">
            <thead>
              <tr>
                <th>Typ</th>
                <th>Kunde</th>
                <th>Anbieter</th>
                <th>Status</th>
                <th>Provision</th>
                <th>Datum</th>
                <th>Aktionen</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((c) => (
                <tr key={c.id}>
                  <td>
                    <span style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      {CONTRACT_TYPES[c.type]?.icon} {CONTRACT_TYPES[c.type]?.label || c.type}
                    </span>
                  </td>
                  <td style={{ color: 'var(--text-primary)', fontWeight: 600 }}>{c.customer_name || '-'}</td>
                  <td>{c.provider || '-'}</td>
                  <td>
                    <select className="form-select" style={{ padding: '4px 28px 4px 8px', fontSize: '12px', background: 'transparent', border: 'none' }}
                      value={c.status} onChange={(e) => handleStatusChange(c.id, e.target.value)}>
                      {Object.entries(STATUS_LABELS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                    </select>
                  </td>
                  <td style={{ color: 'var(--accent-secondary)', fontWeight: 600 }}>
                    {c.commission_amount ? `€${c.commission_amount}` : '-'}
                  </td>
                  <td>{c.created_at ? new Date(c.created_at).toLocaleDateString('de-DE') : '-'}</td>
                  <td>
                    <button className="btn btn-ghost btn-sm">👁️</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="card">
          <div className="empty-state">
            <div className="empty-state-icon">📄</div>
            <h3>Keine Verträge</h3>
            <p>Erstellen Sie Verträge über den Schnellcheck oder manuell</p>
            <button className="btn btn-primary" onClick={() => setShowModal(true)}>+ Neuer Vertrag</button>
          </div>
        </div>
      )}

      {/* Add Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Neuer Vertrag</h3>
              <button className="modal-close" onClick={() => setShowModal(false)}>✕</button>
            </div>
            <div className="modal-body">
              <div className="form-row">
                <div className="form-group">
                  <label>Vertragsart *</label>
                  <select className="form-select" value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })}>
                    {Object.entries(CONTRACT_TYPES).map(([k, v]) => <option key={k} value={k}>{v.icon} {v.label}</option>)}
                  </select>
                </div>
                <div className="form-group">
                  <label>Anbieter</label>
                  <input className="form-input" value={form.provider} onChange={(e) => setForm({ ...form, provider: e.target.value })} placeholder="z.B. Wien Energie" />
                </div>
              </div>
              <div className="form-row">
                <div className="form-group">
                  <label>Kunde</label>
                  <select className="form-select" value={form.customer_id} onChange={(e) => {
                    const cust = customers.find((c) => c.id === e.target.value);
                    setForm({ ...form, customer_id: e.target.value, customer_name: cust?.name || '' });
                  }}>
                    <option value="">Kunde wählen</option>
                    {customers.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
                  </select>
                </div>
                <div className="form-group">
                  <label>Provision (€)</label>
                  <input className="form-input" type="number" value={form.commission_amount} onChange={(e) => setForm({ ...form, commission_amount: e.target.value })} placeholder="0.00" />
                </div>
              </div>
              <div className="form-group">
                <label>Notizen</label>
                <textarea className="form-textarea" value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} placeholder="Vertragsdetails..." />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setShowModal(false)}>Abbrechen</button>
              <button className="btn btn-primary" onClick={handleSave}>Vertrag anlegen</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
