'use client';

import { useState, useEffect } from 'react';
import Sidebar from '@/components/Sidebar';
import { supabase } from '@/lib/supabase';

interface PartnerNode {
  id?: string;
  name: string;
  commission: string;
  leads: number;
  status?: string;
  children: PartnerNode[];
}

// Demo team data removed to ensure only real tree structure is shown

function TreeNode({ node, depth = 0 }: { node: PartnerNode; depth?: number }) {
  const [isExpanded, setIsExpanded] = useState(true);
  const isPending = node.status === 'pending';
  const hasChildren = node.children && node.children.length > 0;

  return (
    <div style={{ marginLeft: depth * 32 }}>
      <div className="tree-node" style={depth === 0 ? { paddingLeft: 0 } : undefined}>
        <div 
          className="tree-node-card" 
          style={{
            ...(depth === 0 ? { border: '2px solid var(--teal)' } : {}),
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: '16px',
            width: '100%',
            maxWidth: '450px'
          }}
          onClick={hasChildren ? () => setIsExpanded(!isExpanded) : undefined}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div className="tree-node-avatar" style={isPending ? { background: 'var(--gray-400)' } : undefined}>
              {node.name.slice(0, 2).toUpperCase()}
            </div>
            <div>
              <div className="tree-node-name">
                {node.name}
                {isPending && <span className="status-badge yellow" style={{ marginLeft: 8, padding: '2px 6px', fontSize: '0.65rem' }}>Eingeladen</span>}
              </div>
              <div className="tree-node-meta" style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '4px' }}>
                <span>Provision: {node.commission} · {node.leads} Leads</span>
                {!isPending && node.id && (
                  <a
                    href={`/team/contract/${node.id}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="status-badge blue"
                    style={{ padding: '2px 6px', fontSize: '0.65rem', textDecoration: 'none', display: 'inline-flex', alignItems: 'center', cursor: 'pointer' }}
                    onClick={(e) => e.stopPropagation()}
                  >
                    📄 Vertrag PDF
                  </a>
                )}
              </div>
            </div>
          </div>
          {hasChildren && (
            <span style={{ fontSize: '0.8rem', color: 'var(--gray-400)', userSelect: 'none', marginRight: '4px' }}>
              {isExpanded ? '▼' : '►'}
            </span>
          )}
        </div>
      </div>
      {hasChildren && isExpanded && node.children.map((child, i) => (
        <TreeNode key={i} node={child} depth={depth + 1} />
      ))}
    </div>
  );
}

export default function TeamPage() {
  const [team, setTeam] = useState<PartnerNode[]>([]);
  const [allPartners, setAllPartners] = useState<any[]>([]);
  const [visiblePartners, setVisiblePartners] = useState<any[]>([]);
  const [isAdmin, setIsAdmin] = useState(false);
  const [activeTab, setActiveTab] = useState<'structure' | 'invitations'>('structure');
  const [searchQuery, setSearchQuery] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [successLink, setSuccessLink] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const [form, setForm] = useState({
    firstName: '',
    lastName: '',
    email: '',
    birthDate: '',
    street: '',
    postalCode: '',
    city: '',
    partnerType: 'person', // 'person' | 'company'
    companyName: '',
    companyAddress: '',
    commissionPercent: '10',
  });

  const loadTeam = async () => {
    const stored = localStorage.getItem('kr_partner');
    if (!stored) return;
    try {
      const loggedInUser = JSON.parse(stored);
      const loggedInEmail = loggedInUser.email;
      const adminCheck = loggedInEmail.toLowerCase().trim() === 'office@konsumentenretter.at';
      setIsAdmin(adminCheck);

      const res = await fetch('/api/team');
      if (!res.ok) throw new Error('API fetch failed');
      const data = await res.json();
      
      if (data && Array.isArray(data)) {
        setAllPartners(data);
        
        const current = data.find(p => p.email.toLowerCase().trim() === loggedInEmail.toLowerCase().trim());
        const partnerMap = new Map<string, PartnerNode>();
        
        // Initialize nodes
        data.forEach((p: any) => {
          partnerMap.set(p.id, {
            id: p.id,
            name: p.company_name ? `${p.first_name} ${p.last_name} (${p.company_name})` : `${p.first_name} ${p.last_name}`,
            commission: `${p.commission_percent}%`,
            leads: p.leads_count || 0,
            status: p.status,
            children: []
          });
        });

        const roots: PartnerNode[] = [];
        
        if (adminCheck) {
          // Admin: show all roots that don't have parents
          data.forEach((p: any) => {
            const node = partnerMap.get(p.id)!;
            if (!p.parent_partner_id) {
              roots.push(node);
            } else if (partnerMap.has(p.parent_partner_id)) {
              partnerMap.get(p.parent_partner_id)!.children.push(node);
            }
          });
        } else if (current) {
          // Partner: show tree starting from self
          data.forEach((p: any) => {
            const node = partnerMap.get(p.id)!;
            if (p.id === current.id) {
              roots.push(node);
            } else if (p.parent_partner_id && partnerMap.has(p.parent_partner_id)) {
              partnerMap.get(p.parent_partner_id)!.children.push(node);
            }
          });
        }

        if (roots.length > 0) {
          setTeam(roots);
        }

        // Helper to get descendant IDs recursively
        const getDescendantIds = (pid: string): string[] => {
          const ids: string[] = [];
          const children = data.filter((p: any) => p.parent_partner_id === pid);
          children.forEach(child => {
            ids.push(child.id);
            ids.push(...getDescendantIds(child.id));
          });
          return ids;
        };

        if (adminCheck) {
          setVisiblePartners(data);
        } else if (current) {
          const teamIds = getDescendantIds(current.id);
          const filtered = data.filter((p: any) => teamIds.includes(p.id));
          setVisiblePartners(filtered);
        } else {
          setVisiblePartners([]);
        }
      }
    } catch (err) {
      console.error('Failed to load team:', err);
    }
  };

  useEffect(() => {
    loadTeam();
  }, []);

  const handleCopyAddress = () => {
    const parts = [
      form.street,
      form.postalCode || form.city ? `${form.postalCode || ''} ${form.city || ''}`.trim() : ''
    ].filter(Boolean);
    
    setForm(prev => ({
      ...prev,
      companyAddress: parts.join(', ')
    }));
  };

  const handleInvite = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setSuccessLink(null);

    const percent = parseFloat(form.commissionPercent);
    if (isNaN(percent) || percent < 0 || percent > 35) {
      alert('Die Provision muss zwischen 0% und 35% liegen.');
      setSubmitting(false);
      return;
    }

    try {
      // Get inviter ID from logged-in partner session
      let parentPartnerId = null;
      let loggedInEmail = '';
      const stored = localStorage.getItem('kr_partner');
      if (stored) {
        try {
          const parsed = JSON.parse(stored);
          loggedInEmail = parsed.email;
          if (parsed.id && parsed.id !== 'admin-root') {
            parentPartnerId = parsed.id;
          }
        } catch (e) {
          console.warn(e);
        }
      }

      // 1. Trigger database insertion and email send via single server-side API route
      const res = await fetch('/api/invite', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: form.email,
          firstName: form.firstName,
          lastName: form.lastName,
          birthDate: form.birthDate,
          street: form.street,
          postalCode: form.postalCode,
          city: form.city,
          partnerType: form.partnerType,
          companyName: form.partnerType === 'company' ? form.companyName : '',
          companyAddress: form.partnerType === 'company' ? form.companyAddress : '',
          commissionPercent: form.commissionPercent,
          parentPartnerId,
          inviterEmail: loggedInEmail
        }),
      });

      if (!res.ok) {
        const errData = await res.json();
        throw new Error(errData.error || 'Serverfehler');
      }

      const inviteResult = await res.json();
      const origin = typeof window !== 'undefined' ? window.location.origin : 'https://konsumentenretter-portal.vercel.app';
      const registrationUrl = `${origin}/register/${inviteResult.inviteId}`;

      // Notify user about email dispatch result
      if (inviteResult.emailSent) {
        alert(`Einladung erfolgreich per E-Mail an ${form.email} gesendet!`);
      } else {
        alert(`Partner in der Datenbank angelegt, aber E-Mail konnte nicht gesendet werden: ${inviteResult.emailError || 'Resend-Fehler'}.\n\nSie können den Registrierungslink kopieren und direkt senden.`);
      }

      // Reload team view dynamically from Supabase database
      await loadTeam();

      setSuccessLink(registrationUrl);
      setIsModalOpen(false);

      // Reset form
      setForm({
        firstName: '',
        lastName: '',
        email: '',
        birthDate: '',
        street: '',
        postalCode: '',
        city: '',
        partnerType: 'person',
        companyName: '',
        companyAddress: '',
        commissionPercent: '10',
      });
    } catch (err: any) {
      console.error(err);
      alert(`Ein Fehler ist aufgetreten: ${err.message}`);
    } finally {
      setSubmitting(false);
    }
  };

  const handleResendInvite = async (partner: any) => {
    if (!confirm(`Möchten Sie die Einladung an ${partner.first_name} ${partner.last_name} (${partner.email}) wirklich erneut senden?`)) {
      return;
    }
    setSubmitting(true);
    setSuccessLink(null);

    try {
      // Get inviter ID from logged-in partner session
      let parentPartnerId = partner.parent_partner_id;
      let loggedInEmail = '';
      const stored = localStorage.getItem('kr_partner');
      if (stored) {
        try {
          const parsed = JSON.parse(stored);
          loggedInEmail = parsed.email;
        } catch (e) {
          console.warn(e);
        }
      }

      const res = await fetch('/api/invite', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: partner.email,
          firstName: partner.first_name,
          lastName: partner.last_name,
          birthDate: partner.birth_date,
          street: partner.street,
          postalCode: partner.postal_code,
          city: partner.city,
          partnerType: partner.partner_type || 'person',
          companyName: partner.company_name || '',
          companyAddress: partner.company_address || '',
          commissionPercent: String(partner.commission_percent),
          parentPartnerId,
          inviterEmail: loggedInEmail,
        }),
      });

      if (!res.ok) {
        const errData = await res.json();
        throw new Error(errData.error || 'Serverfehler');
      }

      const inviteResult = await res.json();
      const origin = typeof window !== 'undefined' ? window.location.origin : 'https://konsumentenretter-portal.vercel.app';
      const registrationUrl = `${origin}/register/${inviteResult.inviteId}`;

      if (inviteResult.emailSent) {
        alert(`Einladung erfolgreich erneut per E-Mail an ${partner.email} gesendet!`);
      } else {
        alert(`Partner-Einladung aktualisiert, aber E-Mail konnte nicht gesendet werden: ${inviteResult.emailError || 'Resend-Fehler'}.\n\nSie können den Registrierungslink kopieren und direkt senden.`);
      }

      // Show copied link banner
      setSuccessLink(registrationUrl);
      await loadTeam();
    } catch (err: any) {
      console.error(err);
      alert(`Ein Fehler ist aufgetreten beim erneuten Senden: ${err.message}`);
    } finally {
      setSubmitting(false);
    }
  };

  // Helper to count descendants recursively
  const countDescendants = (node: PartnerNode): number => {
    let count = 0;
    if (node.children) {
      count += node.children.length;
      node.children.forEach(child => {
        count += countDescendants(child);
      });
    }
    return count;
  };

  // Helper to sum leads recursively
  const sumLeads = (node: PartnerNode): number => {
    let total = node.leads || 0;
    if (node.children) {
      node.children.forEach(child => {
        total += sumLeads(child);
      });
    }
    return total;
  };

  const directPartnersCount = isAdmin ? team.length : (team[0]?.children?.length || 0);
  const totalTeamCount = isAdmin 
    ? (team.length + team.reduce((acc, root) => acc + countDescendants(root), 0))
    : (team[0] ? countDescendants(team[0]) : 0);
  const totalLeadsCount = isAdmin
    ? team.reduce((acc, root) => acc + sumLeads(root), 0)
    : (team[0] ? sumLeads(team[0]) : 0);

  return (
    <div className="app-layout">
      <Sidebar />
      <main className="main-content">
        <div className="page-header">
          <h1>Teamübersicht</h1>
          <button className="btn btn-primary" onClick={() => { setSuccessLink(null); setIsModalOpen(true); }}>
            + Partner einladen
          </button>
        </div>

        {successLink && (
          <div className="table-card" style={{ padding: 24, marginBottom: 24, border: '1px solid var(--green)', background: 'rgba(16,185,129,0.04)' }}>
            <h3 style={{ color: 'var(--green)', display: 'flex', alignItems: 'center', gap: 8 }}>
              ✓ Partner erfolgreich eingeladen!
            </h3>
            <p style={{ fontSize: '0.9rem', marginTop: 10, color: 'var(--gray-600)', lineHeight: '1.5' }}>
              Die Einladung wurde in der Datenbank hinterlegt und eine Onboarding-E-Mail wurde via Resend versendet. Falls der Partner die E-Mail nicht erhalten hat oder Sie den Prozess beschleunigen möchten, können Sie diesen Link kopieren und direkt senden:
            </p>
            <div style={{ display: 'flex', gap: 10, marginTop: 14 }}>
              <input
                readOnly
                value={successLink}
                style={{ flex: 1, padding: '10px 14px', border: '1px solid var(--gray-200)', borderRadius: 'var(--radius-sm)', fontFamily: 'monospace', fontSize: '0.85rem' }}
                onClick={(e) => (e.target as HTMLInputElement).select()}
              />
              <button
                className="btn btn-outline"
                onClick={() => {
                  navigator.clipboard.writeText(successLink);
                  alert('Link in die Zwischenablage kopiert!');
                }}
              >
                Kopieren
              </button>
            </div>
          </div>
        )}

        <div className="stats-grid">
          <div className="stat-card">
            <div className="stat-card-header"><span>Direkte Partner</span><span className="icon">👤</span></div>
            <div className="stat-value">{directPartnersCount}</div>
          </div>
          <div className="stat-card">
            <div className="stat-card-header"><span>Gesamtes Team</span><span className="icon">🏗️</span></div>
            <div className="stat-value">{totalTeamCount}</div>
          </div>
          <div className="stat-card">
            <div className="stat-card-header"><span>Team Leads gesamt</span><span className="icon">👥</span></div>
            <div className="stat-value">{totalLeadsCount}</div>
          </div>
        </div>

        <div className="tabs-container">
          <button
            className={`tab-btn ${activeTab === 'structure' ? 'active' : ''}`}
            onClick={() => setActiveTab('structure')}
          >
            Team-Struktur (Baum)
          </button>
          <button
            className={`tab-btn ${activeTab === 'invitations' ? 'active' : ''}`}
            onClick={() => setActiveTab('invitations')}
          >
            Eingeladene Partner & Status
          </button>
        </div>

        {activeTab === 'structure' ? (
          <div className="table-card" style={{ padding: 24 }}>
            <h3 style={{ marginBottom: 20 }}>Teamstruktur</h3>
            <div className="team-tree">
              {team.map((node, i) => <TreeNode key={i} node={node} />)}
            </div>
          </div>
        ) : (
          <div className="table-card">
            <div className="table-toolbar">
              <h3 style={{ margin: 0 }}>Eingeladene Vertriebspartner</h3>
              <input
                type="text"
                placeholder="Partner suchen..."
                className="search-input"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>
            <div style={{ overflowX: 'auto' }}>
              <table>
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>E-Mail</th>
                    <th>Provision</th>
                    <th>Status</th>
                    <th>Unterschrieben am</th>
                    <th>Eingeladen von</th>
                    <th>Aktionen</th>
                  </tr>
                </thead>
                <tbody>
                  {visiblePartners
                    .filter((p) => {
                      const search = searchQuery.toLowerCase().trim();
                      if (!search) return true;
                      const fullName = `${p.first_name || ''} ${p.last_name || ''}`.toLowerCase();
                      const email = (p.email || '').toLowerCase();
                      const comp = (p.company_name || '').toLowerCase();
                      return fullName.includes(search) || email.includes(search) || comp.includes(search);
                    })
                    .map((p) => {
                      const signedDate = p.contract_signed_at
                        ? new Date(p.contract_signed_at).toLocaleString('de-AT', {
                            dateStyle: 'medium',
                            timeStyle: 'short',
                          })
                        : 'Nein';
                      
                      const inviter = allPartners.find(x => x.id === p.parent_partner_id);
                      const inviterName = inviter
                        ? `${inviter.first_name} ${inviter.last_name}`
                        : 'Direkt / Admin';

                      const isPending = p.status === 'pending';

                      return (
                        <tr key={p.id}>
                          <td>
                            <strong>
                              {p.first_name} {p.last_name}
                            </strong>
                            {p.company_name && (
                              <div style={{ fontSize: '0.8rem', color: 'var(--gray-500)' }}>
                                {p.company_name}
                              </div>
                            )}
                          </td>
                          <td>{p.email}</td>
                          <td>{p.commission_percent}%</td>
                          <td>
                            <span className={`status-badge ${isPending ? 'yellow' : 'green'}`}>
                              {isPending ? 'Eingeladen' : 'Aktiv'}
                            </span>
                          </td>
                          <td>{signedDate}</td>
                          <td style={{ fontSize: '0.85rem', color: 'var(--gray-600)' }}>
                            {inviterName}
                          </td>
                          <td>
                            {isPending && (
                              <button
                                className="btn btn-outline btn-sm"
                                style={{ padding: '4px 8px', fontSize: '0.75rem', height: 'auto', display: 'inline-flex', alignItems: 'center', gap: '4px' }}
                                onClick={() => handleResendInvite(p)}
                                disabled={submitting}
                              >
                                ✉ Erneut senden
                              </button>
                            )}
                          </td>
                        </tr>
                      );
                    })}
                  {visiblePartners.length === 0 && (
                    <tr>
                      <td colSpan={7} style={{ textAlign: 'center', color: 'var(--gray-400)', padding: '32px' }}>
                        Keine Partner gefunden.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </main>

      {/* Invite Modal */}
      {isModalOpen && (
        <div className="modal-overlay" onClick={() => setIsModalOpen(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '520px' }}>
            <h2>Partner einladen</h2>
            <form onSubmit={handleInvite}>
              <div className="form-group" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <div>
                  <label>Vorname *</label>
                  <input
                    required
                    value={form.firstName}
                    onChange={(e) => setForm({ ...form, firstName: e.target.value })}
                    placeholder="Max"
                  />
                </div>
                <div>
                  <label>Nachname *</label>
                  <input
                    required
                    value={form.lastName}
                    onChange={(e) => setForm({ ...form, lastName: e.target.value })}
                    placeholder="Mustermann"
                  />
                </div>
              </div>

              <div className="form-group">
                <label>E-Mail-Adresse *</label>
                <input
                  required
                  type="email"
                  value={form.email}
                  onChange={(e) => setForm({ ...form, email: e.target.value })}
                  placeholder="max@beispiel.at"
                />
              </div>

              <div className="form-group">
                <label>Geburtsdatum *</label>
                <div style={{ display: 'flex', gap: 8 }}>
                  <select
                    required
                    value={form.birthDate ? form.birthDate.split('-')[2] || '' : ''}
                    onChange={(e) => {
                      const parts = (form.birthDate || '--').split('-');
                      setForm({ ...form, birthDate: `${parts[0] || ''}-${parts[1] || ''}-${e.target.value}` });
                    }}
                    style={{ flex: 1 }}
                  >
                    <option value="">Tag</option>
                    {Array.from({ length: 31 }, (_, i) => i + 1).map(d => (
                      <option key={d} value={String(d).padStart(2, '0')}>{d}</option>
                    ))}
                  </select>
                  <select
                    required
                    value={form.birthDate ? form.birthDate.split('-')[1] || '' : ''}
                    onChange={(e) => {
                      const parts = (form.birthDate || '--').split('-');
                      setForm({ ...form, birthDate: `${parts[0] || ''}-${e.target.value}-${parts[2] || ''}` });
                    }}
                    style={{ flex: 1 }}
                  >
                    <option value="">Monat</option>
                    {['Jänner','Februar','März','April','Mai','Juni','Juli','August','September','Oktober','November','Dezember'].map((m, i) => (
                      <option key={i} value={String(i + 1).padStart(2, '0')}>{m}</option>
                    ))}
                  </select>
                  <select
                    required
                    value={form.birthDate ? form.birthDate.split('-')[0] || '' : ''}
                    onChange={(e) => {
                      const parts = (form.birthDate || '--').split('-');
                      setForm({ ...form, birthDate: `${e.target.value}-${parts[1] || ''}-${parts[2] || ''}` });
                    }}
                    style={{ flex: 1 }}
                  >
                    <option value="">Jahr</option>
                    {Array.from({ length: 80 }, (_, i) => new Date().getFullYear() - 18 - i).map(y => (
                      <option key={y} value={String(y)}>{y}</option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="form-group">
                <label>Straße und Hausnummer *</label>
                <input
                  required
                  value={form.street}
                  onChange={(e) => setForm({ ...form, street: e.target.value })}
                  placeholder="Musterstraße 42"
                />
              </div>

              <div className="form-group" style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: 12 }}>
                <div>
                  <label>PLZ *</label>
                  <input
                    required
                    value={form.postalCode}
                    onChange={(e) => setForm({ ...form, postalCode: e.target.value })}
                    placeholder="1010"
                  />
                </div>
                <div>
                  <label>Ort *</label>
                  <input
                    required
                    value={form.city}
                    onChange={(e) => setForm({ ...form, city: e.target.value })}
                    placeholder="Wien"
                  />
                </div>
              </div>

              <div className="form-group">
                <label>Partnertyp *</label>
                <select
                  value={form.partnerType}
                  onChange={(e) => setForm({ ...form, partnerType: e.target.value })}
                >
                  <option value="person">Person</option>
                  <option value="company">Firma</option>
                </select>
              </div>

              {form.partnerType === 'company' && (
                <>
                  <div className="form-group">
                    <label>Firmenname *</label>
                    <input
                      required
                      value={form.companyName}
                      onChange={(e) => setForm({ ...form, companyName: e.target.value })}
                      placeholder="Muster GmbH"
                    />
                  </div>
                  <div className="form-group">
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
                      <label style={{ margin: 0 }}>Firmenadresse *</label>
                      <button
                        type="button"
                        className="btn btn-outline"
                        style={{ padding: '2px 8px', fontSize: '0.75rem', height: 'auto', border: '1px solid var(--gray-300)' }}
                        onClick={handleCopyAddress}
                      >
                        Adresse übernehmen
                      </button>
                    </div>
                    <input
                      required
                      value={form.companyAddress}
                      onChange={(e) => setForm({ ...form, companyAddress: e.target.value })}
                      placeholder="Musterstraße 42, 1010 Wien"
                    />
                  </div>
                </>
              )}

              <div className="form-group">
                <label>Provision (%) *</label>
                <input
                  required
                  type="number"
                  min="0"
                  max="35"
                  step="0.5"
                  value={form.commissionPercent}
                  onChange={(e) => setForm({ ...form, commissionPercent: e.target.value })}
                  placeholder="10"
                />
              </div>

              <div className="modal-actions">
                <button type="button" className="btn btn-outline" onClick={() => setIsModalOpen(false)}>
                  Abbrechen
                </button>
                <button type="submit" className="btn btn-primary" disabled={submitting}>
                  {submitting ? 'Wird eingeladen...' : 'Partner hinzufügen'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
