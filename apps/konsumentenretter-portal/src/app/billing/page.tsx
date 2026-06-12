import Sidebar from '@/components/Sidebar';

export default function BillingPage() {
  return (
    <div className="app-layout">
      <Sidebar />
      <main className="main-content">
        <div className="page-header"><h1>Abrechnung</h1></div>
        <div className="stat-card" style={{ textAlign: 'center', padding: 60 }}>
          <div style={{ fontSize: '3rem', marginBottom: 16 }}>🚧</div>
          <h2 style={{ fontSize: '1.3rem', marginBottom: 8 }}>Kommt bald</h2>
          <p style={{ color: 'var(--gray-500)' }}>Die Abrechnungsfunktion wird in Kürze verfügbar sein. Hier werden Sie Auszahlungen einsehen und Provisionen Ihres Teams nachverfolgen können.</p>
        </div>
      </main>
    </div>
  );
}
