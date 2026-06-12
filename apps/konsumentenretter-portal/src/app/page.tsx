'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabase';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

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
        setError(authError.message === 'Invalid login credentials' ? 'Ungültige E-Mail-Adresse oder Passwort.' : authError.message);
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

  return (
    <div className="login-page">
      <div className="login-card">
        <h1>Konsumenten<span>retter</span></h1>
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
            <label>Passwort</label>
            <input type="password" required value={password} onChange={e => setPassword(e.target.value)} placeholder="••••••••" />
          </div>
          <button type="submit" className="btn btn-primary" disabled={loading}>
            {loading ? 'Anmelden...' : 'Anmelden'}
          </button>
        </form>
      </div>
    </div>
  );
}

