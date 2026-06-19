'use client';
import { useState, useEffect } from 'react';
import Sidebar from '@/components/Sidebar';
import { supabase } from '@/lib/supabase';

interface LeadItem {
  id: string;
  name: string;
  email: string;
  phone: string;
  campaign: 'credit' | 'service' | 'casino';
  bank: string;
  status: string;
  date: string;
}

const campaignLabel: Record<string, { label: string; cls: string }> = {
  credit: { label: 'Kreditgebühren', cls: 'campaign-credit' },
  service: { label: 'Servicep.', cls: 'campaign-service' },
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

export default function LeadsPage() {
  const [leads, setLeads] = useState<LeadItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [campaignFilter, setCampaignFilter] = useState('all');

  useEffect(() => {
    async function fetchLeads() {
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

        let query = supabase.from('leads').select('*');
        if (partnerId && !isAdmin) {
          query = query.eq('ref_partner_id', partnerId);
        }

        const { data, error } = await query;
        if (error) throw error;

        if (data) {
          const campaignMap: Record<string, 'credit' | 'service' | 'casino'> = {
            bearbeitungsgebuehren: 'credit',
            servicepauschalen: 'service',
            casino: 'casino',
          };

          const formatted: LeadItem[] = data.map((lead: any) => {
            let selectionStr = '';
            if (Array.isArray(lead.selections) && lead.selections.length > 0) {
              selectionStr = lead.selections.join(', ');
            }
            return {
              id: lead.id,
              name: `${lead.first_name} ${lead.last_name}`,
              email: lead.email,
              phone: lead.phone || '-',
              campaign: campaignMap[lead.campaign] || 'credit',
              bank: selectionStr || '-',
              status: lead.status || 'kooperationsvertrag',
              date: lead.created_at ? new Date(lead.created_at).toLocaleDateString('de-AT', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '-',
            };
          });
          setLeads(formatted);
        }
      } catch (err) {
        console.error('Error fetching leads:', err);
      } finally {
        setLoading(false);
      }
    }

    fetchLeads();
  }, []);

  const filtered = leads.filter(l => {
    const matchesSearch = l.name.toLowerCase().includes(search.toLowerCase()) || 
                          l.email.toLowerCase().includes(search.toLowerCase());
    const matchesCampaign = campaignFilter === 'all' || l.campaign === campaignFilter;
    return matchesSearch && matchesCampaign;
  });

  return (
    <div className="app-layout">
      <Sidebar />
      <main className="main-content">
        <div className="page-header"><h1>Leadübersicht</h1></div>
        <div className="table-card">
          <div className="table-toolbar">
            <input 
              className="search-input" 
              placeholder="🔍 Suchen nach Name oder E-Mail..." 
              value={search} 
              onChange={e => setSearch(e.target.value)} 
            />
            <div style={{ display: 'flex', gap: 8 }}>
              <select 
                className="search-input" 
                style={{ width: 'auto' }}
                value={campaignFilter}
                onChange={e => setCampaignFilter(e.target.value)}
              >
                <option value="all">Alle Kampagnen</option>
                <option value="credit">Kreditgebühren</option>
                <option value="service">Servicepauschalen</option>
                <option value="casino">Casino</option>
              </select>
            </div>
          </div>
          <div style={{ overflowX: 'auto' }}>
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>E-Mail</th>
                  <th>Telefon</th>
                  <th>Kampagne</th>
                  <th>Bank/Casino</th>
                  <th>Status</th>
                  <th>Datum</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map(l => (
                  <tr key={l.id}>
                    <td style={{ fontWeight: 600 }}>{l.name}</td>
                    <td>{l.email}</td>
                    <td>{l.phone}</td>
                    <td>
                      <span className={`kanban-card-campaign ${campaignLabel[l.campaign]?.cls || 'campaign-credit'}`}>
                        {campaignLabel[l.campaign]?.label || 'Kredit'}
                      </span>
                    </td>
                    <td>{l.bank}</td>
                    <td>
                      <span className={`status-badge ${statusLabel[l.status]?.cls || 'blue'}`}>
                        {statusLabel[l.status]?.label || l.status}
                      </span>
                    </td>
                    <td>{l.date}</td>
                  </tr>
                ))}
                {filtered.length === 0 && !loading && (
                  <tr>
                    <td colSpan={7} style={{ textAlign: 'center', color: 'var(--gray-400)', padding: '32px' }}>
                      Keine Leads gefunden.
                    </td>
                  </tr>
                )}
                {loading && (
                  <tr>
                    <td colSpan={7} style={{ textAlign: 'center', color: 'var(--gray-500)', padding: '32px' }}>
                      Lade Leads...
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
