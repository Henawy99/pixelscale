'use client';

import { useState, useEffect, useRef } from 'react';
import { getCurrentUser } from '@/lib/auth';
import { getLeads, saveLead, deleteLead, importLeads } from '@/lib/store';
import { getUsers } from '@/lib/auth';

const STATUSES = ['new', 'contacted', 'qualified', 'proposal', 'won', 'lost'];
const STATUS_LABELS = {
  new: 'Neu', contacted: 'Kontaktiert', qualified: 'Qualifiziert',
  proposal: 'Angebot', won: 'Gewonnen', lost: 'Verloren',
};

export default function LeadsPage() {
  const [leads, setLeads] = useState([]);
  const [view, setView] = useState('table');
  const [showModal, setShowModal] = useState(false);
  const [showImportModal, setShowImportModal] = useState(false);
  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState('all');
  const [form, setForm] = useState({ name: '', email: '', phone: '', source: '', notes: '', assigned_to: '', status: 'new' });
  const [editId, setEditId] = useState(null);
  const [importText, setImportText] = useState('');
  const fileRef = useRef(null);

  useEffect(() => {
    setLeads(getLeads());
  }, []);

  const users = getUsers();

  const filtered = leads.filter((l) => {
    const matchSearch = l.name?.toLowerCase().includes(search.toLowerCase()) ||
      l.email?.toLowerCase().includes(search.toLowerCase()) ||
      l.phone?.includes(search);
    const matchStatus = filterStatus === 'all' || l.status === filterStatus;
    return matchSearch && matchStatus;
  });

  const handleSave = () => {
    const user = getCurrentUser();
    saveLead({ ...form, id: editId, assigned_by: user?.id, assigned_to: form.assigned_to || user?.id });
    setLeads(getLeads());
    setShowModal(false);
    resetForm();
  };

  const resetForm = () => {
    setForm({ name: '', email: '', phone: '', source: '', notes: '', assigned_to: '', status: 'new' });
    setEditId(null);
  };

  const handleEdit = (lead) => {
    setForm(lead);
    setEditId(lead.id);
    setShowModal(true);
  };

  const handleDelete = (id) => {
    if (confirm('Lead wirklich löschen?')) {
      deleteLead(id);
      setLeads(getLeads());
    }
  };

  const handleStatusChange = (leadId, newStatus) => {
    const lead = leads.find((l) => l.id === leadId);
    if (lead) {
      saveLead({ ...lead, status: newStatus });
      setLeads(getLeads());
    }
  };

  const handleFileImport = (e) => {
    const file = e.target.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (ev) => {
      try {
        const text = ev.target.result;
        const lines = text.split('\n').filter((l) => l.trim());
        if (lines.length < 2) return alert('Datei ist leer oder hat kein gültiges Format');
        
        const headers = lines[0].split(/[,;\t]/).map((h) => h.trim().toLowerCase().replace(/"/g, ''));
        const newLeads = [];
        
        for (let i = 1; i < lines.length; i++) {
          const values = lines[i].split(/[,;\t]/).map((v) => v.trim().replace(/"/g, ''));
          const lead = {};
          headers.forEach((h, idx) => {
            if (h.includes('name') || h.includes('vor')) lead.name = (lead.name ? lead.name + ' ' : '') + (values[idx] || '');
            else if (h.includes('mail') || h.includes('email')) lead.email = values[idx];
            else if (h.includes('tel') || h.includes('phone') || h.includes('mobil')) lead.phone = values[idx];
            else if (h.includes('quelle') || h.includes('source')) lead.source = values[idx];
            else if (h.includes('notiz') || h.includes('note')) lead.notes = values[idx];
          });
          if (lead.name) newLeads.push(lead);
        }
        
        if (newLeads.length > 0) {
          const user = getCurrentUser();
          importLeads(newLeads.map((l) => ({ ...l, assigned_to: user?.id, assigned_by: user?.id })));
          setLeads(getLeads());
          setShowImportModal(false);
          alert(`${newLeads.length} Leads importiert!`);
        }
      } catch (err) {
        alert('Fehler beim Import: ' + err.message);
      }
    };
    reader.readAsText(file);
  };

  const handleTextImport = () => {
    try {
      const lines = importText.split('\n').filter((l) => l.trim());
      const user = getCurrentUser();
      const newLeads = lines.map((line) => {
        const parts = line.split(/[,;\t]/).map((p) => p.trim());
        return {
          name: parts[0] || '',
          email: parts[1] || '',
          phone: parts[2] || '',
          source: parts[3] || 'Import',
          assigned_to: user?.id,
          assigned_by: user?.id,
        };
      }).filter((l) => l.name);

      if (newLeads.length > 0) {
        importLeads(newLeads);
        setLeads(getLeads());
        setShowImportModal(false);
        setImportText('');
        alert(`${newLeads.length} Leads importiert!`);
      }
    } catch (err) {
      alert('Fehler: ' + err.message);
    }
  };

  return (
    <div>
      <div className="page-header">
        <div className="page-header-left">
          <h1>Leads</h1>
          <p>{leads.length} Leads gesamt · {leads.filter((l) => l.status === 'new').length} neu</p>
        </div>
        <div className="page-header-actions">
          <div className="search-bar">
            <span className="icon">🔍</span>
            <input placeholder="Leads suchen..." value={search} onChange={(e) => setSearch(e.target.value)} />
          </div>
          <button className="btn btn-secondary" onClick={() => setShowImportModal(true)}>
            📥 Leads importieren
          </button>
          <button className="btn btn-primary" onClick={() => { setShowModal(true); resetForm(); }}>
            + Neuer Lead
          </button>
        </div>
      </div>

      {/* Filters */}
      <div className="filter-bar">
        <div className="filter-pills">
          <button className={`filter-pill ${filterStatus === 'all' ? 'active' : ''}`} onClick={() => setFilterStatus('all')}>
            Alle ({leads.length})
          </button>
          {STATUSES.map((s) => (
            <button key={s} className={`filter-pill ${filterStatus === s ? 'active' : ''}`} onClick={() => setFilterStatus(s)}>
              {STATUS_LABELS[s]} ({leads.filter((l) => l.status === s).length})
            </button>
          ))}
        </div>
        <div style={{ marginLeft: 'auto', display: 'flex', gap: '4px' }}>
          <button className={`btn btn-ghost btn-sm ${view === 'table' ? '' : ''}`} onClick={() => setView('table')} style={{ opacity: view === 'table' ? 1 : 0.5 }}>📋</button>
          <button className={`btn btn-ghost btn-sm`} onClick={() => setView('pipeline')} style={{ opacity: view === 'pipeline' ? 1 : 0.5 }}>📊</button>
        </div>
      </div>

      {/* Table View */}
      {view === 'table' && (
        filtered.length > 0 ? (
          <div className="table-container">
            <table className="table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>E-Mail</th>
                  <th>Telefon</th>
                  <th>Quelle</th>
                  <th>Status</th>
                  <th>Zugewiesen</th>
                  <th>Datum</th>
                  <th>Aktionen</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((l) => (
                  <tr key={l.id}>
                    <td style={{ color: 'var(--text-primary)', fontWeight: 600 }}>{l.name}</td>
                    <td>{l.email}</td>
                    <td>{l.phone}</td>
                    <td>{l.source || '-'}</td>
                    <td>
                      <select className="form-select" style={{ padding: '4px 28px 4px 8px', fontSize: '12px', background: 'transparent', border: 'none' }}
                        value={l.status} onChange={(e) => handleStatusChange(l.id, e.target.value)}>
                        {STATUSES.map((s) => <option key={s} value={s}>{STATUS_LABELS[s]}</option>)}
                      </select>
                    </td>
                    <td>{users.find((u) => u.id === l.assigned_to)?.full_name || '-'}</td>
                    <td>{l.created_at ? new Date(l.created_at).toLocaleDateString('de-DE') : '-'}</td>
                    <td>
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <button className="btn btn-ghost btn-sm" onClick={() => handleEdit(l)}>✏️</button>
                        <button className="btn btn-ghost btn-sm" onClick={() => handleDelete(l.id)}>🗑️</button>
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
              <div className="empty-state-icon">🎯</div>
              <h3>Keine Leads</h3>
              <p>Fügen Sie neue Leads hinzu oder importieren Sie eine CSV-Datei</p>
              <div style={{ display: 'flex', gap: '12px', justifyContent: 'center' }}>
                <button className="btn btn-secondary" onClick={() => setShowImportModal(true)}>📥 Importieren</button>
                <button className="btn btn-primary" onClick={() => { setShowModal(true); resetForm(); }}>+ Neuer Lead</button>
              </div>
            </div>
          </div>
        )
      )}

      {/* Pipeline View */}
      {view === 'pipeline' && (
        <div className="pipeline">
          {STATUSES.filter((s) => s !== 'lost').map((status) => {
            const statusLeads = leads.filter((l) => l.status === status);
            return (
              <div key={status} className="pipeline-column">
                <div className="pipeline-column-header">
                  <span className="pipeline-column-title">
                    {STATUS_LABELS[status]}
                    <span className="pipeline-column-count">{statusLeads.length}</span>
                  </span>
                </div>
                <div className="pipeline-column-body">
                  {statusLeads.map((lead) => (
                    <div key={lead.id} className="pipeline-card" onClick={() => handleEdit(lead)}>
                      <div className="lead-name">{lead.name}</div>
                      {lead.email && <div className="lead-info">📧 {lead.email}</div>}
                      {lead.phone && <div className="lead-info">📱 {lead.phone}</div>}
                      <div className="lead-date">{lead.created_at ? new Date(lead.created_at).toLocaleDateString('de-DE') : ''}</div>
                    </div>
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Add/Edit Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>{editId ? 'Lead bearbeiten' : 'Neuer Lead'}</h3>
              <button className="modal-close" onClick={() => setShowModal(false)}>✕</button>
            </div>
            <div className="modal-body">
              <div className="form-group">
                <label>Name *</label>
                <input className="form-input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="Name" />
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
                  <label>Quelle</label>
                  <input className="form-input" value={form.source} onChange={(e) => setForm({ ...form, source: e.target.value })} placeholder="z.B. Website, Empfehlung" />
                </div>
                <div className="form-group">
                  <label>Status</label>
                  <select className="form-select" value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })}>
                    {STATUSES.map((s) => <option key={s} value={s}>{STATUS_LABELS[s]}</option>)}
                  </select>
                </div>
              </div>
              <div className="form-group">
                <label>Zuweisen an</label>
                <select className="form-select" value={form.assigned_to} onChange={(e) => setForm({ ...form, assigned_to: e.target.value })}>
                  <option value="">Mir zuweisen</option>
                  {users.filter((u) => u.is_active).map((u) => <option key={u.id} value={u.id}>{u.full_name}</option>)}
                </select>
              </div>
              <div className="form-group">
                <label>Notizen</label>
                <textarea className="form-textarea" value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} placeholder="Notizen zum Lead..." />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setShowModal(false)}>Abbrechen</button>
              <button className="btn btn-primary" onClick={handleSave} disabled={!form.name}>Speichern</button>
            </div>
          </div>
        </div>
      )}

      {/* Import Modal */}
      {showImportModal && (
        <div className="modal-overlay" onClick={() => setShowImportModal(false)}>
          <div className="modal modal-lg" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>📥 Leads importieren</h3>
              <button className="modal-close" onClick={() => setShowImportModal(false)}>✕</button>
            </div>
            <div className="modal-body">
              <div className="file-upload" onClick={() => fileRef.current?.click()}>
                <div className="file-upload-icon">📄</div>
                <h4>CSV-Datei hochladen</h4>
                <p>Spalten: Name, E-Mail, Telefon, Quelle (komma- oder semikolongetrennt)</p>
                <input ref={fileRef} type="file" accept=".csv,.txt,.tsv" style={{ display: 'none' }} onChange={handleFileImport} />
              </div>

              <div className="divider" />

              <div className="form-group">
                <label>Oder manuell einfügen (Name, E-Mail, Telefon pro Zeile)</label>
                <textarea
                  className="form-textarea"
                  style={{ minHeight: '150px' }}
                  placeholder="Max Mustermann, max@beispiel.at, +43 664 1234567&#10;Anna Beispiel, anna@test.at, +43 660 7654321"
                  value={importText}
                  onChange={(e) => setImportText(e.target.value)}
                />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setShowImportModal(false)}>Abbrechen</button>
              <button className="btn btn-primary" onClick={handleTextImport} disabled={!importText.trim()}>
                Importieren
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
