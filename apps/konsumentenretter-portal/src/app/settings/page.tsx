import Sidebar from '@/components/Sidebar';

export default function SettingsPage() {
  return (
    <div className="app-layout">
      <Sidebar />
      <main className="main-content">
        <div className="page-header"><h1>Einstellungen</h1></div>
        <div className="table-card" style={{ padding: 32, maxWidth: 600 }}>
          <h3 style={{ marginBottom: 20 }}>Profil bearbeiten</h3>
          <div style={{ marginBottom: 16 }}>
            <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: 'var(--gray-600)', marginBottom: 6 }}>Vorname</label>
            <input className="search-input" style={{ width: '100%' }} defaultValue="Demo" />
          </div>
          <div style={{ marginBottom: 16 }}>
            <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: 'var(--gray-600)', marginBottom: 6 }}>Nachname</label>
            <input className="search-input" style={{ width: '100%' }} defaultValue="Partner" />
          </div>
          <div style={{ marginBottom: 16 }}>
            <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: 'var(--gray-600)', marginBottom: 6 }}>E-Mail</label>
            <input className="search-input" style={{ width: '100%' }} defaultValue="partner@beispiel.at" readOnly />
          </div>
          <div style={{ marginBottom: 24 }}>
            <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: 'var(--gray-600)', marginBottom: 6 }}>Neues Passwort</label>
            <input className="search-input" type="password" style={{ width: '100%' }} placeholder="••••••••" />
          </div>
          <button className="btn btn-primary">Speichern</button>
        </div>
      </main>
    </div>
  );
}
