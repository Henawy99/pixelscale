'use client';

import { useState, useEffect } from 'react';
import { getCurrentUser } from '@/lib/auth';
import { getDashboardStats } from '@/lib/store';

export default function DashboardPage() {
  const [stats, setStats] = useState(null);
  const [user, setUser] = useState(null);

  useEffect(() => {
    const currentUser = getCurrentUser();
    if (currentUser) {
      setUser(currentUser);
      setStats(getDashboardStats(currentUser.id, currentUser.role));
    }
  }, []);

  if (!stats) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', padding: '60px' }}>
        <div className="loading-spinner" style={{ width: 40, height: 40 }} />
      </div>
    );
  }

  const statCards = [
    {
      label: 'Kunden',
      value: stats.totalCustomers,
      icon: '👥',
      color: 'blue',
      change: '+12%',
      positive: true,
    },
    {
      label: 'Verträge',
      value: stats.totalContracts,
      icon: '📄',
      color: 'green',
      change: `${stats.activeContracts} aktiv`,
      positive: true,
    },
    {
      label: 'Offene Leads',
      value: stats.totalLeads,
      icon: '🎯',
      color: 'amber',
      change: `${stats.openLeads} offen`,
      positive: true,
    },
    {
      label: 'Provisionen',
      value: `€${stats.totalCommissions.toLocaleString('de-DE')}`,
      icon: '💰',
      color: 'purple',
      change: 'Gesamt',
      positive: true,
    },
  ];

  const quickActions = [
    { icon: '⚡', label: 'Neuer Schnellcheck', href: '/dashboard/schnellcheck' },
    { icon: '👤', label: 'Kunde anlegen', href: '/dashboard/kunden' },
    { icon: '🎯', label: 'Lead hinzufügen', href: '/dashboard/leads' },
    { icon: '📄', label: 'Vertrag erstellen', href: '/dashboard/vertraege' },
  ];

  return (
    <div>
      {/* Welcome */}
      <div style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '24px', fontWeight: 800, letterSpacing: '-0.5px' }}>
          Willkommen zurück, {user?.full_name?.split(' ')[0] || user?.username} 👋
        </h2>
        <p style={{ color: 'var(--text-secondary)', fontSize: '14px', marginTop: '4px' }}>
          Hier ist Ihre Übersicht für heute
        </p>
      </div>

      {/* Stats Grid */}
      <div className="stats-grid">
        {statCards.map((stat, i) => (
          <div key={i} className={`stat-card ${stat.color} fade-in stagger-${i + 1}`}>
            <div className="stat-card-header">
              <span className="stat-card-label">{stat.label}</span>
              <div className={`stat-card-icon ${stat.color}`}>{stat.icon}</div>
            </div>
            <div className="stat-card-value">{stat.value}</div>
            <span className={`stat-card-change ${stat.positive ? 'positive' : 'negative'}`}>
              {stat.change}
            </span>
          </div>
        ))}
      </div>

      {/* Quick Actions */}
      <div className="card fade-in" style={{ marginBottom: '24px' }}>
        <div className="card-header">
          <h3 className="card-title">Schnellaktionen</h3>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px' }}>
          {quickActions.map((action, i) => (
            <a
              key={i}
              href={action.href}
              className="btn btn-secondary"
              style={{
                padding: '20px',
                flexDirection: 'column',
                gap: '10px',
                fontSize: '14px',
                textDecoration: 'none',
                height: 'auto',
              }}
            >
              <span style={{ fontSize: '28px' }}>{action.icon}</span>
              {action.label}
            </a>
          ))}
        </div>
      </div>

      {/* Content Grid */}
      <div className="content-grid">
        {/* Recent Contracts */}
        <div className="card fade-in">
          <div className="card-header">
            <h3 className="card-title">Letzte Verträge</h3>
            <a href="/dashboard/vertraege" className="btn btn-ghost btn-sm">
              Alle anzeigen →
            </a>
          </div>
          {stats.recentContracts.length > 0 ? (
            <div className="table-container" style={{ border: 'none' }}>
              <table className="table">
                <thead>
                  <tr>
                    <th>Typ</th>
                    <th>Status</th>
                    <th>Datum</th>
                  </tr>
                </thead>
                <tbody>
                  {stats.recentContracts.map((contract) => (
                    <tr key={contract.id}>
                      <td style={{ color: 'var(--text-primary)', fontWeight: 500 }}>{contract.type}</td>
                      <td>
                        <span className={`badge-status ${contract.status}`}>{contract.status}</span>
                      </td>
                      <td>{new Date(contract.created_at).toLocaleDateString('de-DE')}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="empty-state" style={{ padding: '40px 20px' }}>
              <div className="empty-state-icon">📄</div>
              <h3>Keine Verträge</h3>
              <p>Erstellen Sie Ihren ersten Vertrag über den Schnellcheck</p>
            </div>
          )}
        </div>

        {/* Recent Leads */}
        <div className="card fade-in">
          <div className="card-header">
            <h3 className="card-title">Aktuelle Leads</h3>
            <a href="/dashboard/leads" className="btn btn-ghost btn-sm">
              Alle anzeigen →
            </a>
          </div>
          {stats.recentLeads.length > 0 ? (
            <ul className="activity-list">
              {stats.recentLeads.map((lead) => (
                <li key={lead.id} className="activity-item">
                  <div className="activity-icon blue">🎯</div>
                  <div className="activity-content">
                    <div className="title">{lead.name}</div>
                    <div className="time">
                      {lead.email} · {lead.phone || 'Kein Telefon'}
                    </div>
                  </div>
                  <span className={`badge-status ${lead.status}`}>{lead.status}</span>
                </li>
              ))}
            </ul>
          ) : (
            <div className="empty-state" style={{ padding: '40px 20px' }}>
              <div className="empty-state-icon">🎯</div>
              <h3>Keine Leads</h3>
              <p>Importieren Sie Leads oder fügen Sie neue hinzu</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
