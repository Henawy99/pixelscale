'use client';

import { useState, useEffect } from 'react';
import { getUsers, addUser, updateUser, ROLES, getCurrentUser, getSubordinates } from '@/lib/auth';
import { getContracts, getLeads } from '@/lib/store';

export default function TeamPage() {
  const [users, setUsers] = useState([]);
  const [currentUser, setCurrentUser] = useState(null);
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState({ full_name: '', username: '', password: '', email: '', phone: '', role: 'kundenberater', parent_id: '' });
  const [editId, setEditId] = useState(null);

  useEffect(() => {
    setUsers(getUsers());
    setCurrentUser(getCurrentUser());
  }, []);

  const contracts = getContracts();
  const leads = getLeads();

  const getUserStats = (userId) => {
    const userContracts = contracts.filter((c) => c.created_by === userId);
    const userLeads = leads.filter((l) => l.assigned_to === userId);
    return { contracts: userContracts.length, leads: userLeads.length, activeContracts: userContracts.filter((c) => c.status === 'active').length };
  };

  const handleSave = () => {
    if (editId) {
      updateUser(editId, form);
    } else {
      addUser(form);
    }
    setUsers(getUsers());
    setShowModal(false);
    resetForm();
  };

  const resetForm = () => {
    setForm({ full_name: '', username: '', password: '', email: '', phone: '', role: 'kundenberater', parent_id: '' });
    setEditId(null);
  };

  const handleEdit = (user) => {
    setForm({ ...user });
    setEditId(user.id);
    setShowModal(true);
  };

  const toggleActive = (userId) => {
    const user = users.find((u) => u.id === userId);
    if (user) {
      updateUser(userId, { is_active: !user.is_active });
      setUsers(getUsers());
    }
  };

  const getInitials = (name) => name ? name.split(' ').map((n) => n[0]).join('').toUpperCase() : '?';

  const sortedUsers = [...users].sort((a, b) => {
    const levelA = ROLES[a.role]?.level || 99;
    const levelB = ROLES[b.role]?.level || 99;
    return levelA - levelB;
  });

  return (
    <div>
      <div className="page-header">
        <div className="page-header-left">
          <h1>Team</h1>
          <p>{users.filter((u) => u.is_active).length} aktive Partner</p>
        </div>
        <div className="page-header-actions">
          <button className="btn btn-primary" onClick={() => { setShowModal(true); resetForm(); }}>
            + Neuer Partner
          </button>
        </div>
      </div>

      {/* Hierarchy View */}
      <div className="card" style={{ marginBottom: '24px' }}>
        <div className="card-header">
          <h3 className="card-title">Vertriebsstruktur</h3>
          <span className="card-subtitle">Karriereplan & Provisionen</span>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
          {Object.entries(ROLES).filter(([k]) => k !== 'partner').map(([key, role]) => {
            const roleUsers = users.filter((u) => u.role === key && u.is_active);
            return (
              <div key={key} className={`hierarchy-node level-${role.level}`}>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, fontSize: '14px', color: 'var(--text-primary)' }}>{role.label}</div>
                  <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '2px' }}>
                    {role.rate}% Provision · {roleUsers.length} Partner
                  </div>
                </div>
                <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
                  {roleUsers.map((u) => (
                    <span key={u.id} className="badge-role">{u.full_name}</span>
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Team Grid */}
      <div className="team-grid">
        {sortedUsers.filter((u) => u.is_active).map((user) => {
          const stats = getUserStats(user.id);
          return (
            <div key={user.id} className="team-card fade-in">
              <div className="team-card-avatar" style={{
                background: ROLES[user.role]?.level === 1 ? 'var(--gradient-primary)' :
                  ROLES[user.role]?.level === 2 ? 'linear-gradient(135deg, #8b5cf6, #ec4899)' :
                  ROLES[user.role]?.level === 3 ? 'linear-gradient(135deg, #10b981, #3b82f6)' :
                  ROLES[user.role]?.level === 4 ? 'linear-gradient(135deg, #f59e0b, #ef4444)' :
                  'linear-gradient(135deg, #6b7280, #9ca3af)'
              }}>
                {getInitials(user.full_name)}
              </div>
              <div className="name">{user.full_name}</div>
              <div className="role-badge">
                <span className="badge-role">{ROLES[user.role]?.label || user.role} · {ROLES[user.role]?.rate || 0}%</span>
              </div>
              {user.email && <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '8px' }}>{user.email}</div>}
              <div className="team-card-stats">
                <div className="team-card-stat">
                  <div className="value">{stats.contracts}</div>
                  <div className="label">Verträge</div>
                </div>
                <div className="team-card-stat">
                  <div className="value">{stats.leads}</div>
                  <div className="label">Leads</div>
                </div>
              </div>
              <div style={{ marginTop: '16px', display: 'flex', gap: '8px', justifyContent: 'center' }}>
                <button className="btn btn-ghost btn-sm" onClick={() => handleEdit(user)}>✏️ Bearbeiten</button>
                <button className="btn btn-ghost btn-sm" onClick={() => toggleActive(user.id)} style={{ color: 'var(--accent-danger)' }}>
                  Deaktivieren
                </button>
              </div>
            </div>
          );
        })}
      </div>

      {/* Add/Edit Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>{editId ? 'Partner bearbeiten' : 'Neuer Vertriebspartner'}</h3>
              <button className="modal-close" onClick={() => setShowModal(false)}>✕</button>
            </div>
            <div className="modal-body">
              <div className="form-group">
                <label>Vollständiger Name *</label>
                <input className="form-input" value={form.full_name} onChange={(e) => setForm({ ...form, full_name: e.target.value })} placeholder="Vor- und Nachname" />
              </div>
              <div className="form-row">
                <div className="form-group">
                  <label>Benutzername *</label>
                  <input className="form-input" value={form.username} onChange={(e) => setForm({ ...form, username: e.target.value.toUpperCase() })} placeholder="LOGIN" />
                </div>
                <div className="form-group">
                  <label>Passwort {editId ? '(leer lassen = unverändert)' : '*'}</label>
                  <input className="form-input" type="password" value={form.password || ''} onChange={(e) => setForm({ ...form, password: e.target.value })} placeholder="Passwort" />
                </div>
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
                  <label>Position *</label>
                  <select className="form-select" value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value })}>
                    {Object.entries(ROLES).map(([key, role]) => (
                      <option key={key} value={key}>{role.label} ({role.rate}%)</option>
                    ))}
                  </select>
                </div>
                <div className="form-group">
                  <label>Vorgesetzter</label>
                  <select className="form-select" value={form.parent_id} onChange={(e) => setForm({ ...form, parent_id: e.target.value })}>
                    <option value="">Kein Vorgesetzter</option>
                    {users.filter((u) => u.is_active && u.id !== editId).map((u) => (
                      <option key={u.id} value={u.id}>{u.full_name} ({ROLES[u.role]?.label})</option>
                    ))}
                  </select>
                </div>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setShowModal(false)}>Abbrechen</button>
              <button className="btn btn-primary" onClick={handleSave} disabled={!form.full_name || !form.username}>Speichern</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
