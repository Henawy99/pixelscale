'use client';
import { useState } from 'react';
import Sidebar from '@/components/Sidebar';

const DEMO_LEADS = [
  { id: 1, name: 'Max Mustermann', email: 'max@test.at', phone: '+43 660 1234567', campaign: 'credit', bank: 'BAWAG', status: 'vollstaendig', date: '23.05.2026' },
  { id: 2, name: 'Anna Schmidt', email: 'anna@test.at', phone: '+43 660 2345678', campaign: 'casino', bank: 'Bwin', status: 'unvollstaendig', date: '22.05.2026' },
  { id: 3, name: 'Peter Weber', email: 'peter@test.at', phone: '+43 660 3456789', campaign: 'service', bank: 'A1', status: 'zugesagt', date: '21.05.2026' },
  { id: 4, name: 'Maria Huber', email: 'maria@test.at', phone: '+43 660 4567890', campaign: 'credit', bank: 'Erste/Sparkasse', status: 'vollstaendig', date: '20.05.2026' },
  { id: 5, name: 'Thomas Berger', email: 'thomas@test.at', phone: '+43 660 5678901', campaign: 'casino', bank: 'Mr. Green', status: 'bereit', date: '19.05.2026' },
];

const campaignLabel: Record<string, { label: string; cls: string }> = {
  credit: { label: 'Kreditgebühren', cls: 'campaign-credit' },
  service: { label: 'Servicep.', cls: 'campaign-service' },
  casino: { label: 'Casino', cls: 'campaign-casino' },
};
const statusLabel: Record<string, { label: string; cls: string }> = {
  vollstaendig: { label: 'Vollständig', cls: 'blue' },
  unvollstaendig: { label: 'Unvollständig', cls: 'yellow' },
  zugesagt: { label: 'Zugesagt', cls: 'green' },
  bereit: { label: 'Bereit', cls: 'purple' },
};

export default function LeadsPage() {
  const [search, setSearch] = useState('');
  const filtered = DEMO_LEADS.filter(l => l.name.toLowerCase().includes(search.toLowerCase()) || l.email.toLowerCase().includes(search.toLowerCase()));

  return (
    <div className="app-layout">
      <Sidebar />
      <main className="main-content">
        <div className="page-header"><h1>Leadübersicht</h1></div>
        <div className="table-card">
          <div className="table-toolbar">
            <input className="search-input" placeholder="🔍 Suchen nach Name oder E-Mail..." value={search} onChange={e => setSearch(e.target.value)} />
            <div style={{ display: 'flex', gap: 8 }}>
              <select className="search-input" style={{ width: 'auto' }}><option>Alle Kampagnen</option><option>Kreditgebühren</option><option>Servicepauschalen</option><option>Casino</option></select>
            </div>
          </div>
          <table>
            <thead><tr><th>Name</th><th>E-Mail</th><th>Telefon</th><th>Kampagne</th><th>Bank/Casino</th><th>Status</th><th>Datum</th></tr></thead>
            <tbody>
              {filtered.map(l => (
                <tr key={l.id}>
                  <td style={{ fontWeight: 600 }}>{l.name}</td>
                  <td>{l.email}</td>
                  <td>{l.phone}</td>
                  <td><span className={`kanban-card-campaign ${campaignLabel[l.campaign].cls}`}>{campaignLabel[l.campaign].label}</span></td>
                  <td>{l.bank}</td>
                  <td><span className={`status-badge ${statusLabel[l.status].cls}`}>{statusLabel[l.status].label}</span></td>
                  <td>{l.date}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </main>
    </div>
  );
}
