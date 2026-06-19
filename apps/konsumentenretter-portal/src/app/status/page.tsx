'use client';
import { useState, useRef, useEffect } from 'react';
import Sidebar from '@/components/Sidebar';
import { supabase } from '@/lib/supabase';

interface Card { id: string; name: string; info: string; value: string; campaign: 'credit' | 'service' | 'casino'; phone: string; }

const COLUMNS = [
  { id: 'kooperationsvertrag', title: 'Kooperationsvertrag' },
  { id: 'nur_unterschrieben', title: 'Nur unterschrieben' },
  { id: 'nur_ausweis', title: 'Nur Ausweis' },
  { id: 'nur_vertrag', title: 'Nur Vertrag' },
  { id: 'unvollstaendig', title: 'Unvollständig' },
  { id: 'vollstaendig', title: 'Vollständig' },
  { id: 'zugesagt', title: 'Zugesagt' },
  { id: 'warten_vollmacht', title: 'Warten auf Vollmacht' },
  { id: 'neue_dokumente', title: 'Neue Dokumente' },
  { id: 'bereit', title: 'Bereit für Legalem' },
  { id: 'abgelehnt', title: 'Abgelehnt' },
  { id: 'akt_anlegen', title: 'Akt anlegen' },
  { id: 'akt_angelegt', title: 'Akt angelegt' },
  { id: 'mahnung', title: 'Mahnung' },
];

const INITIAL: Record<string, Card[]> = {
  kooperationsvertrag: [],
  nur_unterschrieben: [],
  nur_ausweis: [],
  nur_vertrag: [],
  unvollstaendig: [],
  vollstaendig: [],
  zugesagt: [],
  warten_vollmacht: [],
  neue_dokumente: [],
  bereit: [],
  abgelehnt: [],
  akt_anlegen: [],
  akt_angelegt: [],
  mahnung: [],
};

// Demo leads removed to ensure only real leads are visible

const campaignCls: Record<string, string> = { credit: 'campaign-credit', service: 'campaign-service', casino: 'campaign-casino' };
const campaignLabel: Record<string, string> = { credit: 'Kredit', service: 'Service', casino: 'Casino' };

export default function StatusPage() {
  const [columns, setColumns] = useState<Record<string, Card[]>>(INITIAL);
  const [filter, setFilter] = useState('all');
  const [loading, setLoading] = useState(true);
  const dragItem = useRef<{ col: string; idx: number } | null>(null);

  useEffect(() => {
    fetchLeads();
  }, []);

  async function fetchLeads() {
    try {
      setLoading(true);
      
      // Get partner from localStorage
      let partnerId = null;
      if (typeof window !== 'undefined') {
        const stored = localStorage.getItem('kr_partner');
        if (stored) {
          try {
            partnerId = JSON.parse(stored).id;
          } catch (e) {
            console.warn('Failed to parse partner ID', e);
          }
        }
      }

      // Query leads table from Supabase
      let query = supabase.from('leads').select('*');
      
      // If we have a specific partner ID, filter by that (except if root/admin)
      if (partnerId && partnerId !== 'admin-root') {
        query = query.eq('ref_partner_id', partnerId);
      }

      const { data, error } = await query;

      if (error) {
        throw error;
      }

      if (data && data.length > 0) {
        // Map DB campaigns to UI campaigns
        const campaignMap: Record<string, 'credit' | 'service' | 'casino'> = {
          bearbeitungsgebuehren: 'credit',
          servicepauschalen: 'service',
          casino: 'casino',
        };

        const grouped: Record<string, Card[]> = { ...INITIAL };
        for (const col of COLUMNS) {
          grouped[col.id] = [];
        }

        data.forEach((lead: any) => {
          const statusVal = lead.status || 'kooperationsvertrag';
          const uiCampaign = campaignMap[lead.campaign] || 'credit';
          
          // Selections value format (displays provider like BAWAG)
          let selectionStr = '';
          if (Array.isArray(lead.selections) && lead.selections.length > 0) {
            selectionStr = lead.selections.join(', ');
          }

          const card: Card = {
            id: lead.id,
            name: `${lead.first_name} ${lead.last_name}`,
            info: selectionStr || '-',
            value: lead.estimated_value ? `€ ${Number(lead.estimated_value).toLocaleString('de-AT')}` : '€ -',
            campaign: uiCampaign,
            phone: lead.phone || '-',
          };

          if (grouped[statusVal]) {
            grouped[statusVal].push(card);
          } else {
            grouped['kooperationsvertrag'].push(card);
          }
        });

        setColumns(grouped);
      } else {
        setColumns(INITIAL);
      }
    } catch (err) {
      console.error('Error loading leads from database:', err);
      setColumns(INITIAL);
    } finally {
      setLoading(false);
    }
  }

  const onDragStart = (col: string, idx: number) => { dragItem.current = { col, idx }; };

  const onDrop = async (targetCol: string) => {
    if (!dragItem.current) return;
    const { col: srcCol, idx } = dragItem.current;
    if (srcCol === targetCol) return;
    const card = columns[srcCol][idx];
    
    // Optimistic UI update
    setColumns(prev => ({
      ...prev,
      [srcCol]: prev[srcCol].filter((_, i) => i !== idx),
      [targetCol]: [...prev[targetCol], card],
    }));

    // Update in Supabase
    if (!card.id.startsWith('mock-')) {
      try {
        const { error } = await supabase
          .from('leads')
          .update({ status: targetCol })
          .eq('id', card.id);
        if (error) throw error;
      } catch (err) {
        console.error('Failed to update lead status in Supabase:', err);
        // Revert UI on failure
        fetchLeads();
      }
    }

    dragItem.current = null;
  };

  return (
    <div className="app-layout">
      <Sidebar />
      <main className="main-content">
        <div className="page-header"><h1>Statusübersicht</h1></div>
        <div className="kanban-toolbar">
          <select value={filter} onChange={e => setFilter(e.target.value)}>
            <option value="all">Alle Verträge</option>
            <option value="mine">Meine Verträge</option>
            <option value="team">Team Verträge</option>
          </select>
          <input type="date" />
          <input type="date" />
        </div>
        <div className="kanban-board">
          {COLUMNS.map(col => {
            const cards = columns[col.id] || [];
            return (
              <div key={col.id} className="kanban-column"
                onDragOver={e => e.preventDefault()}
                onDrop={() => onDrop(col.id)}>
                <div className="kanban-column-header">
                  <span className="kanban-column-title">{col.title}</span>
                  <span className="kanban-column-count">{cards.length}</span>
                </div>
                <div className="kanban-cards">
                  {cards.map((card, idx) => (
                    <div key={card.id} className="kanban-card" draggable
                      onDragStart={() => onDragStart(col.id, idx)}>
                      <div className="kanban-card-name">{card.name}</div>
                      <div className="kanban-card-info">{card.info} · {card.phone}</div>
                      <div className="kanban-card-meta">
                        <span className="kanban-card-value">{card.value}</span>
                        <span className={`kanban-card-campaign ${campaignCls[card.campaign]}`}>{campaignLabel[card.campaign]}</span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      </main>
    </div>
  );
}
