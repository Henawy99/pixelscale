'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabase';

const translateAuthError = (message: string): string => {
  const msg = message.toLowerCase();
  if (msg.includes('invalid login credentials') || msg.includes('invalid credentials')) {
    return 'Ungültige E-Mail-Adresse oder Passwort.';
  }
  if (msg.includes('email not found') || msg.includes('user not found')) {
    return 'Es wurde kein Partner mit dieser E-Mail-Adresse gefunden.';
  }
  if (msg.includes('rate limit')) {
    return 'Zu viele Anfragen. Bitte warte einen Moment und versuche es erneut.';
  }
  return 'Ein Fehler ist aufgetreten. Bitte versuche es erneut.';
};

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [view, setView] = useState<'login' | 'forgot'>('login');
  const [successMessage, setSuccessMessage] = useState('');

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      // 1. Attempt Supabase Auth login
      const { data, error: authError } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (data?.user && !authError) {
        // Fetch partner name from partners table
        const { data: partnerData } = await supabase
          .from('partners')
          .select('first_name, last_name, id')
          .eq('auth_user_id', data.user.id)
          .single();

        localStorage.setItem(
          'kr_partner',
          JSON.stringify({
            email: data.user.email,
            name: partnerData ? `${partnerData.first_name} ${partnerData.last_name}` : 'Partner',
            id: partnerData?.id || data.user.id,
          })
        );
        router.push('/dashboard');
        return;
      }

      // 2. Fallback check for the specific admin details requested by user
      if (email.toLowerCase().trim() === 'office@konsumentenretter.at' && password === '123456') {
        localStorage.setItem(
          'kr_partner',
          JSON.stringify({
            email: 'office@konsumentenretter.at',
            name: 'Krist & Partner (Admin)',
            id: 'admin-root',
          })
        );
        router.push('/dashboard');
        return;
      }

      if (authError) {
        setError(translateAuthError(authError.message));
      } else {
        setError('Ungültige Anmeldedaten.');
      }
    } catch (err) {
      // Local fallback for offline/development mode
      if (email.toLowerCase().trim() === 'office@konsumentenretter.at' && password === '123456') {
        localStorage.setItem(
          'kr_partner',
          JSON.stringify({
            email: 'office@konsumentenretter.at',
            name: 'Krist & Partner (Admin)',
            id: 'admin-root',
          })
        );
        router.push('/dashboard');
      } else {
        setError('Fehler bei der Anmeldung. Bitte überprüfen Sie Ihre Internetverbindung.');
      }
    } finally {
      setLoading(false);
    }
  };

  const handleResetPasswordRequest = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setSuccessMessage('');

    try {
      const origin = typeof window !== 'undefined' ? window.location.origin : 'https://konsumentenretter-portal.vercel.app';
      const res = await fetch('/api/reset-password-request', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email,
          redirectTo: `${origin}/reset-password`,
        }),
      });

      if (!res.ok) {
        const errData = await res.json();
        throw new Error(errData.error || 'Serverfehler beim Senden');
      }

      const result = await res.json();
      if (result.emailError) {
        throw new Error(result.emailError);
      }

      setSuccessMessage('Ein Link zum Zurücksetzen Ihres Passworts wurde an Ihre E-Mail-Adresse gesendet.');
    } catch (err: any) {
      setError(err.message || 'Fehler beim Senden des Links. Bitte versuchen Sie es erneut.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <h1>Konsumenten<span>retter</span></h1>
        {view === 'login' ? (
          <>
            <p className="login-subtitle">Partner Portal – Anmelden</p>
            
            {error && (
              <div style={{ color: 'var(--red)', background: 'rgba(239,68,68,0.1)', padding: '10px', borderRadius: 'var(--radius-sm)', fontSize: '0.85rem', marginBottom: '16px', textAlign: 'center' }}>
                {error}
              </div>
            )}

            <form className="login-form" onSubmit={handleLogin}>
              <div className="form-group">
                <label>E-Mail</label>
                <input type="email" required value={email} onChange={e => setEmail(e.target.value)} placeholder="partner@beispiel.at" />
              </div>
              <div className="form-group">
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                  <label style={{ margin: 0 }}>Passwort</label>
                  <button type="button" onClick={() => { setView('forgot'); setError(''); setSuccessMessage(''); }} style={{ background: 'none', border: 'none', color: 'var(--teal)', fontSize: '0.8rem', cursor: 'pointer' }}>
                    Passwort vergessen?
                  </button>
                </div>
                <input type="password" required value={password} onChange={e => setPassword(e.target.value)} placeholder="••••••••" />
              </div>
              <button type="submit" className="btn btn-primary" disabled={loading}>
                {loading ? 'Anmelden...' : 'Anmelden'}
              </button>
            </form>
          </>
        ) : (
          <>
            <p className="login-subtitle">Passwort zurücksetzen</p>
            
            {error && (
              <div style={{ color: 'var(--red)', background: 'rgba(239,68,68,0.1)', padding: '10px', borderRadius: 'var(--radius-sm)', fontSize: '0.85rem', marginBottom: '16px', textAlign: 'center' }}>
                {error}
              </div>
            )}

            {successMessage && (
              <div style={{ color: 'var(--green)', background: 'rgba(16,185,129,0.1)', padding: '10px', borderRadius: 'var(--radius-sm)', fontSize: '0.85rem', marginBottom: '16px', textAlign: 'center' }}>
                {successMessage}
              </div>
            )}

            <form className="login-form" onSubmit={handleResetPasswordRequest}>
              <div className="form-group">
                <label>E-Mail-Adresse</label>
                <input type="email" required value={email} onChange={e => setEmail(e.target.value)} placeholder="partner@beispiel.at" />
              </div>
              <button type="submit" className="btn btn-primary" disabled={loading}>
                {loading ? 'Senden...' : 'Link senden'}
              </button>
              <button type="button" className="btn btn-outline" style={{ width: '100%', marginTop: '8px' }} onClick={() => { setView('login'); setError(''); setSuccessMessage(''); }}>
                Zurück zum Login
              </button>
            </form>
          </>
        )}
      </div>
    </div>
  );
}

