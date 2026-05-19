'use client';

import { useState, useEffect } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import { getCurrentUser, logout, ROLES } from '@/lib/auth';

const NAV_ITEMS = [
  { key: 'main', label: 'HAUPTMENÜ' },
  { key: 'dashboard', path: '/dashboard', icon: '📊', label: 'Dashboard' },
  { key: 'schnellcheck', path: '/dashboard/schnellcheck', icon: '⚡', label: 'Schnellcheck' },
  { key: 'customers', path: '/dashboard/kunden', icon: '👥', label: 'Kunden' },
  { key: 'divider1', label: 'VERTRÄGE' },
  { key: 'contracts', path: '/dashboard/vertraege', icon: '📄', label: 'Alle Verträge' },
  { key: 'energy', path: '/dashboard/vertraege/energie', icon: '🔌', label: 'Strom & Gas' },
  { key: 'internet', path: '/dashboard/vertraege/internet', icon: '🌐', label: 'Internet & TV' },
  { key: 'insurance', path: '/dashboard/vertraege/versicherung', icon: '🛡️', label: 'Versicherung' },
  { key: 'finance', path: '/dashboard/vertraege/finanzierung', icon: '🏦', label: 'Finanzierung' },
  { key: 'divider2', label: 'VERTRIEB' },
  { key: 'leads', path: '/dashboard/leads', icon: '🎯', label: 'Leads' },
  { key: 'team', path: '/dashboard/team', icon: '👨‍👩‍👧‍👦', label: 'Team' },
  { key: 'commissions', path: '/dashboard/provisionen', icon: '💰', label: 'Provisionen' },
];

export default function DashboardLayout({ children }) {
  const [user, setUser] = useState(null);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    const currentUser = getCurrentUser();
    if (!currentUser) {
      router.push('/');
      return;
    }
    setUser(currentUser);
  }, [router]);

  const handleLogout = () => {
    logout();
    router.push('/');
  };

  if (!user) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100vh' }}>
        <div className="loading-spinner" style={{ width: 40, height: 40 }} />
      </div>
    );
  }

  const userInitials = user.full_name
    ? user.full_name
        .split(' ')
        .map((n) => n[0])
        .join('')
        .toUpperCase()
    : user.username?.[0]?.toUpperCase() || 'U';

  const roleLabel = ROLES[user.role]?.label || user.role;

  const getPageTitle = () => {
    const item = NAV_ITEMS.find((n) => n.path === pathname);
    return item?.label || 'Dashboard';
  };

  return (
    <div className="app-layout">
      {/* Mobile overlay */}
      {sidebarOpen && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(0,0,0,0.5)',
            zIndex: 99,
          }}
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside className={`sidebar ${sidebarOpen ? 'open' : ''}`}>
        <div className="sidebar-header">
          <div className="sidebar-brand">
            <div className="sidebar-brand-icon">⚡</div>
            <div className="sidebar-brand-text">
              <h2>TARIFO</h2>
              <span>CRM Platform</span>
            </div>
          </div>
        </div>

        <nav className="sidebar-nav">
          {NAV_ITEMS.map((item) => {
            if (!item.path) {
              return (
                <div key={item.key} className="sidebar-section-label">
                  {item.label}
                </div>
              );
            }

            const isActive = pathname === item.path || 
              (item.path !== '/dashboard' && pathname.startsWith(item.path));

            return (
              <button
                key={item.key}
                className={`sidebar-link ${isActive ? 'active' : ''}`}
                onClick={() => {
                  router.push(item.path);
                  setSidebarOpen(false);
                }}
              >
                <span className="link-icon">{item.icon}</span>
                {item.label}
              </button>
            );
          })}
        </nav>

        <div className="sidebar-footer">
          <div className="sidebar-user" onClick={handleLogout} title="Abmelden">
            <div className="sidebar-user-avatar">{userInitials}</div>
            <div className="sidebar-user-info">
              <div className="name">{user.full_name || user.username}</div>
              <div className="role">{roleLabel}</div>
            </div>
            <span style={{ color: 'var(--text-muted)', fontSize: '16px' }}>🚪</span>
          </div>
        </div>
      </aside>

      {/* Main Content */}
      <div className="main-content">
        <header className="topbar">
          <div className="topbar-left">
            <button className="mobile-menu-btn" onClick={() => setSidebarOpen(!sidebarOpen)}>
              ☰
            </button>
            <h1 className="topbar-title">{getPageTitle()}</h1>
          </div>
          <div className="topbar-right">
            <button className="topbar-btn" title="Benachrichtigungen">
              🔔
              <span className="notification-dot" />
            </button>
            <button className="topbar-btn" onClick={handleLogout} title="Abmelden">
              🚪
            </button>
          </div>
        </header>

        <main className="page-content">{children}</main>
      </div>
    </div>
  );
}
