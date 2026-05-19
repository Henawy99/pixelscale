'use client';

import { useState, useEffect } from 'react';
import { getSchnellchecks } from '@/lib/store';

export default function FinanzierungPage() {
  const [checks, setChecks] = useState([]);

  useEffect(() => {
    const all = getSchnellchecks().filter((s) => 
      s.finanzierung_data?.existing_credits?.length > 0 || s.finanzierung_data?.credit_wishes
    );
    setChecks(all);
  }, []);

  return (
    <div>
      <div className="page-header">
        <div className="page-header-left">
          <h1>Finanzierungen</h1>
          <p>Kreditanfragen aus Schnellchecks für Finanzierungspartner</p>
        </div>
      </div>

      <div style={{ padding: '20px', background: 'rgba(245,158,11,0.06)', border: '1px solid rgba(245,158,11,0.15)', borderRadius: 'var(--radius-lg)', marginBottom: '24px' }}>
        <h4 style={{ fontSize: '14px', fontWeight: 600, marginBottom: '8px' }}>🏦 Partnerbearbeitung</h4>
        <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
          Finanzierungsanfragen aus Schnellchecks werden hier gesammelt und an den Finanzierungspartner weitergeleitet.
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
              {check.finanzierung_data?.existing_credits?.length > 0 && (
                <div style={{ marginBottom: '12px' }}>
                  <span style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-secondary)' }}>Bestehende Kredite:</span>
                  {check.finanzierung_data.existing_credits.map((c, i) => (
                    <div key={i} style={{ padding: '10px 14px', background: 'var(--bg-elevated)', borderRadius: 'var(--radius-sm)', marginTop: '6px', fontSize: '13px' }}>
                      <strong>{c.type}</strong> · €{c.betrag} · Rate: €{c.rate}/Mo · Laufzeit: {c.laufzeit} Monate
                    </div>
                  ))}
                </div>
              )}
              {check.finanzierung_data?.credit_wishes && (
                <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
                  <strong>Kreditwünsche:</strong> {check.finanzierung_data.credit_wishes}
                </p>
              )}
            </div>
          ))}
        </div>
      ) : (
        <div className="card">
          <div className="empty-state">
            <div className="empty-state-icon">🏦</div>
            <h3>Keine Finanzierungsanfragen</h3>
            <p>Führen Sie einen Schnellcheck durch um Finanzierungsdaten zu erfassen</p>
          </div>
        </div>
      )}
    </div>
  );
}
