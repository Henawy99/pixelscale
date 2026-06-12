'use client';
import { useState, useRef } from 'react';
import Sidebar from '@/components/Sidebar';

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
  kooperationsvertrag: [{ id: '1', name: 'Max Mustermann', info: 'BAWAG', value: '€ 2.400', campaign: 'credit', phone: '+43 660 123' }],
  nur_unterschrieben: [{ id: '2', name: 'Anna Schmidt', info: 'Bwin', value: '€ 8.500', campaign: 'casino', phone: '+43 660 234' }],
  nur_ausweis: [],
  nur_vertrag: [{ id: '3', name: 'Peter Weber', info: 'A1', value: '€ 180', campaign: 'service', phone: '+43 660 345' }],
  unvollstaendig: [{ id: '4', name: 'Maria Huber', info: 'Erste', value: '€ 1.800', campaign: 'credit', phone: '+43 660 456' }, { id: '5', name: 'Stefan Lang', info: 'LeoVegas', value: '€ 12.000', campaign: 'casino', phone: '+43 660 567' }],
  vollstaendig: [{ id: '6', name: 'Lisa Braun', info: 'Raiffeisen', value: '€ 3.200', campaign: 'credit', phone: '+43 660 678' }],
  zugesagt: [{ id: '7', name: 'Karl Moser', info: 'Magenta', value: '€ 240', campaign: 'service', phone: '+43 660 789' }],
  warten_vollmacht: [],
  neue_dokumente: [{ id: '8', name: 'Eva Gruber', info: 'Bank Austria', value: '€ 4.100', campaign: 'credit', phone: '+43 660 890' }],
  bereit: [],
  abgelehnt: [],
  akt_anlegen: [{ id: '9', name: 'Hans Bauer', info: 'Mr. Green', value: '€ 6.700', campaign: 'casino', phone: '+43 660 901' }],
  akt_angelegt: [],
  mahnung: [],
};

const campaignCls: Record<string, string> = { credit: 'campaign-credit', service: 'campaign-service', casino: 'campaign-casino' };
const campaignLabel: Record<string, string> = { credit: 'Kredit', service: 'Service', casino: 'Casino' };

export default function StatusPage() {
  const [columns, setColumns] = useState(INITIAL);
  const [filter, setFilter] = useState('all');
  const dragItem = useRef<{ col: string; idx: number } | null>(null);

  const onDragStart = (col: string, idx: number) => { dragItem.current = { col, idx }; };

  const onDrop = (targetCol: string) => {
    if (!dragItem.current) return;
    const { col: srcCol, idx } = dragItem.current;
    if (srcCol === targetCol) return;
    const card = columns[srcCol][idx];
    setColumns(prev => ({
      ...prev,
      [srcCol]: prev[srcCol].filter((_, i) => i !== idx),
      [targetCol]: [...prev[targetCol], card],
    }));
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
