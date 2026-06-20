'use client';
import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabase';

const translateAuthError = (message: string): string => {
  const msg = message.toLowerCase();
  if (msg.includes('should be different') || msg.includes('different from')) {
    return 'Das neue Passwort muss sich vom alten Passwort unterscheiden.';
  }
  if (msg.includes('at least 6 characters') || msg.includes('too short')) {
    return 'Das Passwort muss mindestens 6 Zeichen lang sein.';
  }
  if (msg.includes('too weak') || msg.includes('strength')) {
    return 'Das gewählte Passwort ist zu schwach.';
  }
  if (msg.includes('session') || msg.includes('token') || msg.includes('expired') || msg.includes('invalid')) {
    return 'Deine Wiederherstellungssitzung ist abgelaufen oder ungültig. Bitte fordere einen neuen Passwort-Reset-Link an.';
  }
  if (msg.includes('rate limit')) {
    return 'Zu viele Anfragen. Bitte warte einen Moment und versuche es erneut.';
  }
  return 'Ein Fehler ist beim Zurücksetzen aufgetreten. Bitte versuche es erneut.';
};

export default function ResetPasswordPage() {
  const router = useRouter();
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Check if we are actually in a reset session (optional but nice)
  useEffect(() => {
    const checkSession = async () => {
      const { data } = await supabase.auth.getSession();
      if (!data.session) {
        // Session might not be parsed from URL fragment immediately
      }
    };
    checkSession();
  }, []);

  const handleResetPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    if (password !== confirmPassword) {
      setError('Die Passwörter stimmen nicht überein.');
      return;
    }
    if (password.length < 6) {
      setError('Das Passwort muss mindestens 6 Zeichen lang sein.');
      return;
    }

    setLoading(true);
    setError('');
    setSuccess('');

    try {
      const { error: updateError } = await supabase.auth.updateUser({
        password: password,
      });

      if (updateError) {
        setError(translateAuthError(updateError.message));
      } else {
        setSuccess('Ihr Passwort wurde erfolgreich zurückgesetzt. Sie werden gleich zum Login weitergeleitet.');
        
        // Clear local storage and sign out to ensure clean state
        localStorage.removeItem('kr_partner');
        await supabase.auth.signOut();

        setTimeout(() => {
          router.push('/');
        }, 3000);
      }
    } catch (err: any) {
      setError('Fehler beim Aktualisieren des Passworts. Bitte versuchen Sie es erneut.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <h1>Konsumenten<span>retter</span></h1>
        <p className="login-subtitle">Neues Passwort festlegen</p>
        
        {error && (
          <div style={{ color: 'var(--red)', background: 'rgba(239,68,68,0.1)', padding: '10px', borderRadius: 'var(--radius-sm)', fontSize: '0.85rem', marginBottom: '16px', textAlign: 'center' }}>
            {error}
          </div>
        )}

        {success && (
          <div style={{ color: 'var(--green)', background: 'rgba(16,185,129,0.1)', padding: '10px', borderRadius: 'var(--radius-sm)', fontSize: '0.85rem', marginBottom: '16px', textAlign: 'center' }}>
            {success}
          </div>
        )}

        {!success && (
          <form className="login-form" onSubmit={handleResetPassword}>
            <div className="form-group">
              <label>Neues Passwort</label>
              <input type="password" required value={password} onChange={e => setPassword(e.target.value)} placeholder="••••••••" />
            </div>
            <div className="form-group">
              <label>Passwort bestätigen</label>
              <input type="password" required value={confirmPassword} onChange={e => setConfirmPassword(e.target.value)} placeholder="••••••••" />
            </div>
            <button type="submit" className="btn btn-primary" disabled={loading}>
              {loading ? 'Speichern...' : 'Passwort speichern'}
            </button>
          </form>
        )}
      </div>
    </div>
  );
}
