'use client';
import { useState, useEffect } from 'react';
import Sidebar from '@/components/Sidebar';
import { supabase } from '@/lib/supabase';

interface LeadItem {
  id: string;
  name: string;
  campaign: string;
  status: string;
  date: string;
}

const campaignLabel: Record<string, { label: string; cls: string }> = {
  bearbeitungsgebuehren: { label: 'Kreditgebühren', cls: 'campaign-credit' },
  servicepauschalen: { label: 'Servicepauschale', cls: 'campaign-service' },
  casino: { label: 'Casino', cls: 'campaign-casino' },
};

const statusLabel: Record<string, { label: string; cls: string }> = {
  kooperationsvertrag: { label: 'Kooperationsvertrag', cls: 'blue' },
  nur_unterschrieben: { label: 'Nur unterschrieben', cls: 'yellow' },
  nur_ausweis: { label: 'Nur Ausweis', cls: 'yellow' },
  nur_vertrag: { label: 'Nur Vertrag', cls: 'yellow' },
  unvollstaendig: { label: 'Unvollständig', cls: 'yellow' },
  vollstaendig: { label: 'Vollständig', cls: 'blue' },
  zugesagt: { label: 'Zugesagt', cls: 'green' },
  warten_vollmacht: { label: 'Warten auf Vollmacht', cls: 'purple' },
  neue_dokumente: { label: 'Neue Dokumente', cls: 'blue' },
  bereit: { label: 'Bereit', cls: 'purple' },
  abgelehnt: { label: 'Abgelehnt', cls: 'red' },
  akt_anlegen: { label: 'Akt anlegen', cls: 'blue' },
  akt_angelegt: { label: 'Akt angelegt', cls: 'green' },
  mahnung: { label: 'Mahnung', cls: 'red' },
};

export default function DashboardPage() {
  const [rawData, setRawData] = useState<{
    myLeads: any[];
    teamLeads: any[];
    directPartners: any[];
    allTeamPartners: any[];
  }>({
    myLeads: [],
    teamLeads: [],
    directPartners: [],
    allTeamPartners: []
  });

  const [myLeadsFilter, setMyLeadsFilter] = useState<'all' | '7d' | 'month'>('all');
  const [teamLeadsFilter, setTeamLeadsFilter] = useState<'all' | '7d' | 'month'>('all');
  const [completedFilter, setCompletedFilter] = useState<'all' | '7d' | 'month'>('all');
  const [partnersFilter, setPartnersFilter] = useState<'all' | '7d' | 'month'>('all');

  const [latestLeads, setLatestLeads] = useState<LeadItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadDashboardData() {
      try {
        setLoading(true);
        let loggedInUser = null;
        if (typeof window !== 'undefined') {
          const stored = localStorage.getItem('kr_partner');
          if (stored) {
            try {
              loggedInUser = JSON.parse(stored);
            } catch (e) {
              console.warn('Failed to parse partner ID', e);
            }
          }
        }

        if (!loggedInUser || !loggedInUser.email) {
          setLoading(false);
          return;
        }

        const res = await fetch(`/api/dashboard-data?email=${encodeURIComponent(loggedInUser.email)}`);
        if (!res.ok) throw new Error('Failed to fetch dashboard data');
        const dashboardData = await res.json();

        setRawData({
          myLeads: dashboardData.myLeads || [],
          teamLeads: dashboardData.teamLeads || [],
          directPartners: dashboardData.directPartners || [],
          allTeamPartners: dashboardData.allTeamPartners || []
        });

        if (dashboardData.myLeads) {
          // Sort by created_at desc and take top 5
          const sorted = [...dashboardData.myLeads].sort((a: any, b: any) => 
            new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
          ).slice(0, 5);

          const latest = sorted.map((lead: any) => ({
            id: lead.id,
            name: `${lead.first_name} ${lead.last_name}`,
            campaign: lead.campaign,
            status: lead.status || 'kooperationsvertrag',
            date: lead.created_at ? new Date(lead.created_at).toLocaleDateString('de-AT', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '-',
          }));
          setLatestLeads(latest);
        }

      } catch (err) {
        console.error('Error loading dashboard data:', err);
      } finally {
        setLoading(false);
      }
    }

    loadDashboardData();
  }, []);

  const filterByTimeframe = (items: any[], filter: 'all' | '7d' | 'month') => {
    if (filter === 'all') return items;
    const now = new Date();
    if (filter === '7d') {
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(now.getDate() - 7);
      return items.filter(item => new Date(item.created_at) >= sevenDaysAgo);
    }
    if (filter === 'month') {
      const firstDayOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
      return items.filter(item => new Date(item.created_at) >= firstDayOfMonth);
    }
    return items;
  };

  const currentMyLeadsCount = filterByTimeframe(rawData.myLeads, myLeadsFilter).length;
  const currentTeamLeadsCount = filterByTimeframe(rawData.teamLeads, teamLeadsFilter).length;

  const allLeads = [...rawData.myLeads, ...rawData.teamLeads];
  const completedLeads = allLeads.filter(l => 
    l.status === 'zugesagt' || l.status === 'bereit' || l.status === 'akt_angelegt'
  );
  const currentCompletedCount = filterByTimeframe(completedLeads, completedFilter).length;
  const currentPartnersCount = filterByTimeframe(rawData.directPartners, partnersFilter).length;

  const renderTimeframeSelector = (currentFilter: 'all' | '7d' | 'month', setFilter: (f: 'all' | '7d' | 'month') => void) => (
    <div className="timeframe-selector">
      <button type="button" className={currentFilter === 'all' ? 'active' : ''} onClick={() => setFilter('all')}>Gesamt</button>
      <button type="button" className={currentFilter === '7d' ? 'active' : ''} onClick={() => setFilter('7d')}>7 Tage</button>
      <button type="button" className={currentFilter === 'month' ? 'active' : ''} onClick={() => setFilter('month')}>Monat</button>
    </div>
  );

  return (
    <div className="app-layout">
      <Sidebar />
      <main className="main-content">
        <div className="page-header"><h1>Dashboard</h1></div>
        <div className="stats-grid">
          <div className="stat-card">
            <div className="stat-card-header"><span>Meine Leads</span><span className="icon">👥</span></div>
            <div className="stat-value">{loading ? '...' : currentMyLeadsCount}</div>
            {renderTimeframeSelector(myLeadsFilter, setMyLeadsFilter)}
          </div>
          <div className="stat-card">
            <div className="stat-card-header"><span>Team Leads</span><span className="icon">🏗️</span></div>
            <div className="stat-value">{loading ? '...' : currentTeamLeadsCount}</div>
            {renderTimeframeSelector(teamLeadsFilter, setTeamLeadsFilter)}
          </div>
          <div className="stat-card">
            <div className="stat-card-header"><span>Abgeschlossen</span><span className="icon">✅</span></div>
            <div className="stat-value">{loading ? '...' : currentCompletedCount}</div>
            {renderTimeframeSelector(completedFilter, setCompletedFilter)}
          </div>
          <div className="stat-card">
            <div className="stat-card-header"><span>Direkte Partner</span><span className="icon">🤝</span></div>
            <div className="stat-value">{loading ? '...' : currentPartnersCount}</div>
            {renderTimeframeSelector(partnersFilter, setPartnersFilter)}
          </div>
        </div>
        <div className="table-card">
          <div className="table-toolbar"><h3 style={{ fontSize: '1rem' }}>Neueste Leads</h3></div>
          <div style={{ overflowX: 'auto' }}>
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Kampagne</th>
                  <th>Status</th>
                  <th>Datum</th>
                </tr>
              </thead>
              <tbody>
                {latestLeads.map(l => (
                  <tr key={l.id}>
                    <td>{l.name}</td>
                    <td>
                      <span className={`kanban-card-campaign ${campaignLabel[l.campaign]?.cls || 'campaign-credit'}`}>
                        {campaignLabel[l.campaign]?.label || 'Kreditgebühren'}
                      </span>
                    </td>
                    <td>
                      <span className={`status-badge ${statusLabel[l.status]?.cls || 'blue'}`}>
                        {statusLabel[l.status]?.label || l.status}
                      </span>
                    </td>
                    <td>{l.date}</td>
                  </tr>
                ))}
                {latestLeads.length === 0 && !loading && (
                  <tr>
                    <td colSpan={4} style={{ textAlign: 'center', color: 'var(--gray-400)', padding: '32px' }}>
                      Keine Leads vorhanden.
                    </td>
                  </tr>
                )}
                {loading && (
                  <tr>
                    <td colSpan={4} style={{ textAlign: 'center', color: 'var(--gray-500)', padding: '24px' }}>
                      Lade neueste Leads...
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      </main>
    </div>
  );
}
