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
  const [stats, setStats] = useState({
    myLeads: 0,
    teamLeads: 0,
    completedLeads: 0,
    teamMembers: 0,
  });
  const [latestLeads, setLatestLeads] = useState<LeadItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadDashboardData() {
      try {
        setLoading(true);
        let partnerId = null;
        let isAdmin = false;
        if (typeof window !== 'undefined') {
          const stored = localStorage.getItem('kr_partner');
          if (stored) {
            try {
              const parsed = JSON.parse(stored);
              partnerId = parsed.id;
              isAdmin = parsed.email?.toLowerCase().trim() === 'office@konsumentenretter.at';
            } catch (e) {
              console.warn('Failed to parse partner ID', e);
            }
          }
        }

        // 1. Fetch leads
        let leadsQuery = supabase.from('leads').select('*');
        if (partnerId && !isAdmin) {
          leadsQuery = leadsQuery.eq('ref_partner_id', partnerId);
        }
        const { data: leadsData, error: leadsError } = await leadsQuery;
        if (leadsError) throw leadsError;

        // 2. Fetch direct partners
        let partnersQuery = supabase.from('partners').select('*');
        if (partnerId && !isAdmin) {
          partnersQuery = partnersQuery.eq('parent_partner_id', partnerId);
        }
        const { data: partnersData, error: partnersError } = await partnersQuery;

        let myLeadsCount = 0;
        let completedCount = 0;
        let latest: LeadItem[] = [];

        if (leadsData) {
          myLeadsCount = leadsData.length;
          completedCount = leadsData.filter((l: any) => 
            l.status === 'zugesagt' || l.status === 'bereit' || l.status === 'akt_angelegt'
          ).length;

          // Sort by created_at desc and take top 5
          const sorted = [...leadsData].sort((a: any, b: any) => 
            new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
          ).slice(0, 5);

          latest = sorted.map((lead: any) => ({
            id: lead.id,
            name: `${lead.first_name} ${lead.last_name}`,
            campaign: lead.campaign,
            status: lead.status || 'kooperationsvertrag',
            date: lead.created_at ? new Date(lead.created_at).toLocaleDateString('de-AT', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '-',
          }));
        }

        let teamMembersCount = 0;
        if (partnersData) {
          teamMembersCount = partnersData.length;
        }

        setStats({
          myLeads: myLeadsCount,
          teamLeads: isAdmin ? myLeadsCount : 0, // Admin sees all leads, so team leads equals total leads. Otherwise, under RLS non-admins can't see team leads directly
          completedLeads: completedCount,
          teamMembers: teamMembersCount,
        });
        setLatestLeads(latest);

      } catch (err) {
        console.error('Error loading dashboard data:', err);
      } finally {
        setLoading(false);
      }
    }

    loadDashboardData();
  }, []);

  return (
    <div className="app-layout">
      <Sidebar />
      <main className="main-content">
        <div className="page-header"><h1>Dashboard</h1></div>
        <div className="stats-grid">
          <div className="stat-card">
            <div className="stat-card-header"><span>Meine Leads</span><span className="icon">👥</span></div>
            <div className="stat-value">{loading ? '...' : stats.myLeads}</div>
            <div className="stat-change">{loading ? '' : 'Gesamt'}</div>
          </div>
          <div className="stat-card">
            <div className="stat-card-header"><span>Team Leads</span><span className="icon">🏗️</span></div>
            <div className="stat-value">{loading ? '...' : stats.teamLeads}</div>
            <div className="stat-change">{loading ? '' : 'Gesamt'}</div>
          </div>
          <div className="stat-card">
            <div className="stat-card-header"><span>Abgeschlossen</span><span className="icon">✅</span></div>
            <div className="stat-value">{loading ? '...' : stats.completedLeads}</div>
            <div className="stat-change">{loading ? '' : 'Zusagen & Bereit'}</div>
          </div>
          <div className="stat-card">
            <div className="stat-card-header"><span>Direkte Partner</span><span className="icon">🤝</span></div>
            <div className="stat-value">{loading ? '...' : stats.teamMembers}</div>
            <div className="stat-change">{loading ? '' : 'Eingeladen / Aktiv'}</div>
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
