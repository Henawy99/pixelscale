import Sidebar from '@/components/Sidebar';

export default function DashboardPage() {
  return (
    <div className="app-layout">
      <Sidebar />
      <main className="main-content">
        <div className="page-header"><h1>Dashboard</h1></div>
        <div className="stats-grid">
          <div className="stat-card">
            <div className="stat-card-header"><span>Meine Leads</span><span className="icon">👥</span></div>
            <div className="stat-value">24</div>
            <div className="stat-change">+3 diese Woche</div>
          </div>
          <div className="stat-card">
            <div className="stat-card-header"><span>Team Leads</span><span className="icon">🏗️</span></div>
            <div className="stat-value">87</div>
            <div className="stat-change">+12 diese Woche</div>
          </div>
          <div className="stat-card">
            <div className="stat-card-header"><span>Abgeschlossen</span><span className="icon">✅</span></div>
            <div className="stat-value">15</div>
          </div>
          <div className="stat-card">
            <div className="stat-card-header"><span>Team Mitglieder</span><span className="icon">🤝</span></div>
            <div className="stat-value">6</div>
          </div>
        </div>
        <div className="table-card">
          <div className="table-toolbar"><h3 style={{ fontSize: '1rem' }}>Neueste Leads</h3></div>
          <table>
            <thead><tr><th>Name</th><th>Kampagne</th><th>Status</th><th>Datum</th></tr></thead>
            <tbody>
              <tr><td>Max Mustermann</td><td><span className="kanban-card-campaign campaign-credit">Kreditgebühren</span></td><td><span className="status-badge blue">Vollständig</span></td><td>23.05.2026</td></tr>
              <tr><td>Anna Schmidt</td><td><span className="kanban-card-campaign campaign-casino">Casino</span></td><td><span className="status-badge yellow">Unvollständig</span></td><td>22.05.2026</td></tr>
              <tr><td>Peter Weber</td><td><span className="kanban-card-campaign campaign-service">Servicep.</span></td><td><span className="status-badge green">Zugesagt</span></td><td>21.05.2026</td></tr>
            </tbody>
          </table>
        </div>
      </main>
    </div>
  );
}
