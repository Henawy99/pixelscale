'use client';

import { useState, useEffect } from 'react';
import { getSchnellchecks } from '@/lib/store';

export default function VersicherungPage() {
  const [checks, setChecks] = useState([]);

  useEffect(() => {
    const all = getSchnellchecks().filter((s) => 
      s.versicherung_data?.existing_contracts?.length > 0 || s.versicherung_data?.notes
    );
    setChecks(all);
  }, []);

  return (
    <div>
      <div className="page-header">
        <div className="page-header-left">
          <h1>Versicherungen</h1>
          <p>Anfragen aus Schnellchecks für Versicherungspartner</p>
        </div>
      </div>

      <div style={{ padding: '20px', background: 'rgba(139,92,246,0.06)', border: '1px solid rgba(139,92,246,0.15)', borderRadius: 'var(--radius-lg)', marginBottom: '24px' }}>
        <h4 style={{ fontSize: '14px', fontWeight: 600, marginBottom: '8px' }}>🛡️ Partnerbearbeitung</h4>
        <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
          Versicherungsanfragen aus Schnellchecks werden hier gesammelt und an den Versicherungspartner weitergeleitet. 
          Partner erhalten einen eigenen Zugang um den Status zu bearbeiten.
        </p>
      </div>

      {checks.length > 0 ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          {checks.map((check) => (
            <div key={check.id} className="card">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '12px' }}>
                <div>
                  <h4 style={{ fontWeight: 700 }}>{check.customer_name || 'Unbekannter Kunde'}</h4>
                  <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                    Schnellcheck vom {check.created_at ? new Date(check.created_at).toLocaleDateString('de-DE') : '-'}
                  </span>
                </div>
                <span className={`badge-status ${check.status}`}>{check.status}</span>
              </div>
              {check.versicherung_data?.existing_contracts?.length > 0 && (
                <div style={{ marginBottom: '12px' }}>
                  <span style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-secondary)' }}>Bestehende Verträge:</span>
                  <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginTop: '6px' }}>
                    {check.versicherung_data.existing_contracts.map((c, i) => (
                      <span key={i} className="badge-role">{c.type} · {c.anbieter} {c.kosten && `· €${c.kosten}/Mo`}</span>
                    ))}
                  </div>
                </div>
              )}
              {check.versicherung_data?.preference && (
                <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
                  <strong>Wunsch:</strong> {check.versicherung_data.preference}
                </p>
              )}
              {check.versicherung_data?.notes && (
                <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                  <strong>Notizen:</strong> {check.versicherung_data.notes}
                </p>
              )}
              <div style={{ display: 'flex', gap: '4px', marginTop: '12px' }}>
                {check.versicherung_data?.consent_signature && <span className="badge-status active">✓ Einverständnis</span>}
                {check.versicherung_data?.privacy_signature && <span className="badge-status active">✓ Datenschutz</span>}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="card">
          <div className="empty-state">
            <div className="empty-state-icon">🛡️</div>
            <h3>Keine Versicherungsanfragen</h3>
            <p>Führen Sie einen Schnellcheck durch um Versicherungsdaten zu erfassen</p>
          </div>
        </div>
      )}
    </div>
  );
}
