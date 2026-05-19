'use client';

import { useState, useEffect } from 'react';
import { getCurrentUser, calculateCommissions, getUsers, ROLES } from '@/lib/auth';
import { getContracts, getCommissions, saveCommission } from '@/lib/store';

export default function ProvisionenPage() {
  const [contracts, setContracts] = useState([]);
  const [commissions, setCommissions] = useState([]);
  const [users, setUsers] = useState([]);
  const [currentUser, setCurrentUser] = useState(null);
  const [showCalcModal, setShowCalcModal] = useState(false);
  const [calcAmount, setCalcAmount] = useState('');
  const [calcUserId, setCalcUserId] = useState('');
  const [calcResult, setCalcResult] = useState(null);

  useEffect(() => {
    setContracts(getContracts());
    setCommissions(getCommissions());
    setUsers(getUsers());
    setCurrentUser(getCurrentUser());
  }, []);

  const handleCalculate = () => {
    const amount = parseFloat(calcAmount);
    if (!amount || !calcUserId) return;
    const result = calculateCommissions(calcUserId, amount);
    setCalcResult(result);
  };

  const totalPending = commissions.filter((c) => c.status === 'pending').reduce((s, c) => s + (c.amount || 0), 0);
  const totalPaid = commissions.filter((c) => c.status === 'paid').reduce((s, c) => s + (c.amount || 0), 0);
  const totalAll = commissions.reduce((s, c) => s + (c.amount || 0), 0);

  return (
    <div>
      <div className="page-header">
        <div className="page-header-left">
          <h1>Provisionen</h1>
          <p>Provisionsberechnung & Übersicht</p>
        </div>
        <div className="page-header-actions">
          <button className="btn btn-primary" onClick={() => setShowCalcModal(true)}>
            🧮 Provision berechnen
          </button>
        </div>
      </div>

      {/* Stats */}
      <div className="stats-grid">
        <div className="stat-card green fade-in">
          <div className="stat-card-header">
            <span className="stat-card-label">Gesamt</span>
            <div className="stat-card-icon green">💰</div>
          </div>
          <div className="stat-card-value">€{totalAll.toLocaleString('de-DE')}</div>
        </div>
        <div className="stat-card amber fade-in stagger-1">
          <div className="stat-card-header">
            <span className="stat-card-label">Ausstehend</span>
            <div className="stat-card-icon amber">⏳</div>
          </div>
          <div className="stat-card-value">€{totalPending.toLocaleString('de-DE')}</div>
        </div>
        <div className="stat-card blue fade-in stagger-2">
          <div className="stat-card-header">
            <span className="stat-card-label">Ausgezahlt</span>
            <div className="stat-card-icon blue">✅</div>
          </div>
          <div className="stat-card-value">€{totalPaid.toLocaleString('de-DE')}</div>
        </div>
      </div>

      {/* Commission Structure Explanation */}
      <div className="card fade-in" style={{ marginBottom: '24px' }}>
        <div className="card-header">
          <h3 className="card-title">Karriereplan & Provisionsstruktur</h3>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
          {Object.entries(ROLES).filter(([k]) => k !== 'partner').map(([key, role], i) => (
            <div key={key} style={{
              display: 'flex', alignItems: 'center', gap: '16px', padding: '14px 18px',
              background: 'var(--bg-elevated)', borderRadius: 'var(--radius-md)',
              borderLeft: `3px solid ${i === 0 ? 'var(--accent-primary)' : i === 1 ? 'var(--accent-purple)' : i === 2 ? 'var(--accent-secondary)' : i === 3 ? 'var(--accent-warning)' : 'var(--accent-pink)'}`,
            }}>
              <div style={{
                width: '40px', height: '40px', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center',
                background: i === 0 ? 'rgba(59,130,246,0.15)' : i === 1 ? 'rgba(139,92,246,0.15)' : 'rgba(16,185,129,0.15)',
                fontWeight: 800, fontSize: '16px', color: 'var(--text-primary)',
              }}>
                {i + 1}
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 700, fontSize: '14px' }}>{role.label}</div>
                <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                  {users.filter((u) => u.role === key && u.is_active).length} Partner in dieser Position
                </div>
              </div>
              <div style={{
                padding: '6px 16px', borderRadius: 'var(--radius-full)',
                background: 'rgba(16,185,129,0.12)', color: 'var(--accent-secondary)',
                fontWeight: 800, fontSize: '16px',
              }}>
                {role.rate}%
              </div>
            </div>
          ))}
        </div>

        <div style={{
          marginTop: '20px', padding: '16px', background: 'rgba(59,130,246,0.06)',
          border: '1px solid rgba(59,130,246,0.15)', borderRadius: 'var(--radius-md)',
        }}>
          <h4 style={{ fontSize: '14px', fontWeight: 600, marginBottom: '8px' }}>💡 Leitungsvergütung</h4>
          <p style={{ fontSize: '13px', color: 'var(--text-secondary)', lineHeight: 1.7 }}>
            Wenn ein Vertriebspartner einen Vertrag abschließt, erhält die jeweilige Führungskraft die Differenz als Leitungsvergütung.
            <br />
            <strong>Beispiel:</strong> Kundenberater (60%) schließt einen Vertrag → bekommt 60% der Provision. 
            Der Sales Manager (70%) bekommt 10% (70-60%). 
            Ist kein Senior Sales Manager vorhanden, bekommt der Sales Director 30% (100-70%).
          </p>
        </div>
      </div>

      {/* Commissions Table */}
      {commissions.length > 0 ? (
        <div className="card fade-in">
          <div className="card-header">
            <h3 className="card-title">Provisionshistorie</h3>
          </div>
          <div className="table-container" style={{ border: 'none' }}>
            <table className="table">
              <thead>
                <tr>
                  <th>Partner</th>
                  <th>Typ</th>
                  <th>Rate</th>
                  <th>Betrag</th>
                  <th>Status</th>
                  <th>Datum</th>
                </tr>
              </thead>
              <tbody>
                {commissions.map((c) => (
                  <tr key={c.id}>
                    <td style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{c.user_name || '-'}</td>
                    <td><span className={`badge-status ${c.type === 'direct' ? 'active' : 'proposal'}`}>{c.type === 'direct' ? 'Direkt' : 'Leitungsbonus'}</span></td>
                    <td>{c.rate}%</td>
                    <td style={{ fontWeight: 700, color: 'var(--accent-secondary)' }}>€{c.amount?.toFixed(2)}</td>
                    <td><span className={`badge-status ${c.status}`}>{c.status === 'pending' ? 'Ausstehend' : 'Ausgezahlt'}</span></td>
                    <td>{c.created_at ? new Date(c.created_at).toLocaleDateString('de-DE') : '-'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        <div className="card">
          <div className="empty-state">
            <div className="empty-state-icon">💰</div>
            <h3>Keine Provisionen</h3>
            <p>Provisionen werden automatisch berechnet wenn Verträge abgeschlossen werden</p>
          </div>
        </div>
      )}

      {/* Calculator Modal */}
      {showCalcModal && (
        <div className="modal-overlay" onClick={() => setShowCalcModal(false)}>
          <div className="modal modal-lg" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>🧮 Provisionsrechner</h3>
              <button className="modal-close" onClick={() => setShowCalcModal(false)}>✕</button>
            </div>
            <div className="modal-body">
              <div className="form-row">
                <div className="form-group">
                  <label>Vertriebspartner</label>
                  <select className="form-select" value={calcUserId} onChange={(e) => { setCalcUserId(e.target.value); setCalcResult(null); }}>
                    <option value="">Partner wählen</option>
                    {users.filter((u) => u.is_active).map((u) => (
                      <option key={u.id} value={u.id}>{u.full_name} ({ROLES[u.role]?.label})</option>
                    ))}
                  </select>
                </div>
                <div className="form-group">
                  <label>Gesamtprovision (€)</label>
                  <div style={{ display: 'flex', gap: 8 }}>
                    <input className="form-input" type="number" value={calcAmount} onChange={(e) => { setCalcAmount(e.target.value); setCalcResult(null); }} placeholder="z.B. 500" />
                    <button className="btn btn-primary" onClick={handleCalculate} disabled={!calcAmount || !calcUserId}>
                      Berechnen
                    </button>
                  </div>
                </div>
              </div>

              {calcResult && (
                <div style={{ marginTop: '20px' }}>
                  <h4 style={{ fontSize: '15px', fontWeight: 700, marginBottom: '12px' }}>Provisionsaufteilung</h4>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    {calcResult.map((c, i) => (
                      <div key={i} style={{
                        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                        padding: '14px 18px', background: 'var(--bg-elevated)', borderRadius: 'var(--radius-md)',
                        borderLeft: `3px solid ${c.type === 'direct' ? 'var(--accent-primary)' : 'var(--accent-purple)'}`,
                      }}>
                        <div>
                          <span style={{ fontWeight: 700 }}>{c.user_name}</span>
                          <span style={{ color: 'var(--text-muted)', marginLeft: '8px', fontSize: '13px' }}>
                            {ROLES[c.role]?.label} · {c.type === 'direct' ? 'Direkt' : 'Leitungsbonus'}
                          </span>
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                          <span style={{ color: 'var(--text-secondary)' }}>{c.rate}%</span>
                          <span style={{ fontWeight: 800, fontSize: '18px', color: 'var(--accent-secondary)' }}>€{c.amount.toFixed(2)}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                  <div style={{
                    marginTop: '16px', padding: '14px 18px', background: 'rgba(16,185,129,0.06)',
                    border: '1px solid rgba(16,185,129,0.2)', borderRadius: 'var(--radius-md)',
                    display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                  }}>
                    <span style={{ fontWeight: 600 }}>Verteilung gesamt</span>
                    <span style={{ fontWeight: 800, fontSize: '18px', color: 'var(--accent-secondary)' }}>
                      €{calcResult.reduce((s, c) => s + c.amount, 0).toFixed(2)} / €{calcAmount}
                    </span>
                  </div>
                </div>
              )}
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setShowCalcModal(false)}>Schließen</button>
              {calcResult && (
                <button className="btn btn-success" onClick={() => {
                  calcResult.forEach((c) => saveCommission(c));
                  setCommissions(getCommissions());
                  setShowCalcModal(false);
                  setCalcResult(null);
                  setCalcAmount('');
                  setCalcUserId('');
                }}>
                  Provisionen buchen
                </button>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
