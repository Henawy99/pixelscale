'use client';

import { use, useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabase';
import SignaturePad from '@/components/SignaturePad';

interface PageProps {
  params: Promise<{ id: string }>;
}

export default function RegisterPartnerPage({ params }: PageProps) {
  const resolvedParams = use(params);
  const inviteId = resolvedParams.id;
  const router = useRouter();

  const [loading, setLoading] = useState(true);
  const [signing, setSigning] = useState(false);
  const [signedSuccess, setSignedSuccess] = useState(false);
  const [partner, setPartner] = useState({
    id: inviteId,
    firstName: 'Max',
    lastName: 'Mustermann',
    email: 'max@beispiel.at',
    birthDate: '1990-01-01',
    street: 'Mustergasse 12',
    postalCode: '1010',
    city: 'Wien',
    partnerType: 'person', // 'person' | 'company'
    companyName: '',
    companyAddress: '',
    commissionPercent: 10,
  });

  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [signature, setSignature] = useState('');

  useEffect(() => {
    async function fetchPartner() {
      try {
        const res = await fetch(`/api/partner/${inviteId}`);
        if (res.ok) {
          const data = await res.json();
          setPartner({
            id: data.id,
            firstName: data.first_name,
            lastName: data.last_name,
            email: data.email,
            birthDate: data.birth_date || '',
            street: data.street || '',
            postalCode: data.postal_code || '',
            city: data.city || '',
            partnerType: data.partner_type || 'person',
            companyName: data.company_name || '',
            companyAddress: data.company_address || '',
            commissionPercent: Number(data.commission_percent) || 10,
          });
        } else {
          console.warn('Failed to load invited partner via API:', res.statusText);
        }
      } catch (err) {
        console.warn('Could not load invited partner from database, using demo defaults:', err);
      } finally {
        setLoading(false);
      }
    }
    fetchPartner();
  }, [inviteId]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!signature) {
      alert('Bitte unterschreiben Sie den Vertrag, um fortzufahren.');
      return;
    }

    if (password !== confirmPassword) {
      alert('Die Passwörter stimmen nicht überein.');
      return;
    }

    if (password.length < 6) {
      alert('Das Passwort muss mindestens 6 Zeichen lang sein.');
      return;
    }

    setSigning(true);

    try {
      let authUserId = null;

      // 1. Sign up the user via Supabase Auth
      try {
        const { data: authData, error: authError } = await supabase.auth.signUp({
          email: partner.email,
          password: password,
        });

        if (authError) {
          console.warn('Supabase Auth warning/failure:', authError.message);
        }
        if (authData?.user) {
          authUserId = authData.user.id;
        }
      } catch (authErr) {
        console.warn('Supabase integration skipped or failed during local/offline demo:', authErr);
      }

      // 2. Update partner record via server-side API (bypassing client-side RLS restriction)
      const updateRes = await fetch(`/api/register/${inviteId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          authUserId: authUserId,
          signature: signature,
        }),
      });

      if (!updateRes.ok) {
        const errData = await updateRes.json();
        throw new Error(errData.error || 'Fehler beim Speichern der Registrierungsdaten.');
      }

      setSignedSuccess(true);
    } catch (err: any) {
      console.error(err);
      alert(`Registrierung fehlgeschlagen: ${err.message}`);
    } finally {
      setSigning(false);
    }
  };

  if (loading) {
    return (
      <div className="login-page" style={{ color: 'var(--white)' }}>
        Lade Einladungsdaten...
      </div>
    );
  }

  if (signedSuccess) {
    return (
      <div className="login-page">
        <div className="login-card" style={{ maxWidth: '560px', textAlign: 'center' }}>
          <div style={{ fontSize: '3rem', marginBottom: 16 }}>🎉</div>
          <h1 style={{ marginBottom: 12 }}>Vertrag unterzeichnet!</h1>
          <p style={{ color: 'var(--gray-600)', marginBottom: 24, fontSize: '0.95rem', lineHeight: '1.6' }}>
            Willkommen im Team! Ihr Vertriebspartner-Vertrag wurde erfolgreich unterzeichnet und Ihr Benutzerkonto wurde angelegt. Sie können sich jetzt anmelden.
          </p>
          <button className="btn btn-primary" onClick={() => router.push('/')}>
            Zum Login
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="login-page" style={{ padding: '40px 20px', minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div className="login-card" style={{ maxWidth: '720px', width: '100%', padding: '32px' }}>
        <h1 style={{ textAlign: 'left', fontSize: '1.5rem', marginBottom: 6 }}>
          Vertriebspartner-Registrierung
        </h1>
        <p style={{ color: 'var(--gray-500)', fontSize: '0.9rem', marginBottom: 24 }}>
          Bitte prüfen Sie die Vertragsbedingungen, leisten Sie Ihre digitale Unterschrift und vergeben Sie ein Passwort für Ihren Portal-Zugang.
        </p>

        <form onSubmit={handleSubmit}>
          {/* Section 1: Partner Details Summary */}
          <div style={{ background: 'var(--gray-50)', padding: 16, borderRadius: 'var(--radius)', border: '1px solid var(--gray-200)', marginBottom: 24 }}>
            <h3 style={{ fontSize: '0.85rem', color: 'var(--navy)', textTransform: 'uppercase', letterSpacing: '0.5px', marginBottom: 12 }}>
              Ihre Partnerdaten
            </h3>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px 24px', fontSize: '0.9rem' }}>
              <div><strong>Name:</strong> {partner.firstName} {partner.lastName}</div>
              <div><strong>E-Mail:</strong> {partner.email}</div>
              <div><strong>Geburtsdatum:</strong> {partner.birthDate}</div>
              <div><strong>Adresse:</strong> {partner.street}, {partner.postalCode} {partner.city}</div>
              <div><strong>Partnertyp:</strong> {partner.partnerType === 'company' ? 'Firma' : 'Person'}</div>
              {partner.partnerType === 'company' && (
                <>
                  <div><strong>Firmenname:</strong> {partner.companyName}</div>
                  <div><strong>Firmenadresse:</strong> {partner.companyAddress}</div>
                </>
              )}
              <div><strong>Beteiligungsquote:</strong> {partner.commissionPercent}%</div>
            </div>
          </div>

          {/* Section 2: Scrollable Contract */}
          <div style={{ marginBottom: 24 }}>
            <label style={{ display: 'block', fontWeight: 600, fontSize: '0.85rem', color: 'var(--gray-600)', marginBottom: 8 }}>
              Kooperationsvereinbarung für Vertriebspartner
            </label>
            <div style={{
              height: '320px',
              overflowY: 'scroll',
              border: '1px solid var(--gray-200)',
              borderRadius: 'var(--radius-sm)',
              padding: '16px',
              background: 'var(--white)',
              fontSize: '0.82rem',
              color: 'var(--gray-700)',
              lineHeight: '1.6',
            }}>
              <h3 style={{ fontSize: '1.05rem', fontWeight: 'bold', textAlign: 'center', marginBottom: 20, color: 'var(--navy)' }}>
                VERTRIEBSVEREINBARUNG FÜR PROZESSFINANZIERUNG
              </h3>
              
              <p style={{ marginBottom: 14 }}>
                zwischen<br />
                <strong>Krist & Partner GmbH</strong><br />
                Faradaygasse 6<br />
                1030 Wien<br />
                – nachfolgend „Auftraggeber“ –
              </p>
              
              <p style={{ marginBottom: 14 }}>
                und<br />
                {partner.partnerType === 'company' ? (
                  <>
                    <strong>{partner.companyName}</strong><br />
                    {partner.companyAddress}<br />
                    {partner.firstName && partner.lastName ? `vertreten durch ${partner.firstName} ${partner.lastName}` : ''}<br />
                  </>
                ) : (
                  <>
                    <strong>{partner.firstName} {partner.lastName}</strong><br />
                    {partner.street ? `${partner.street}, ` : ''}{partner.postalCode} {partner.city}<br />
                  </>
                )}
                – nachfolgend „Vertriebspartner“ –
              </p>
              
              <p style={{ marginBottom: 20 }}>
                gemeinsam „Vertragsparteien“.
              </p>

              <h4 style={{ fontWeight: 'bold', marginTop: 16, marginBottom: 8 }}>§ 1 Vertragsgegenstand</h4>
              <p style={{ marginBottom: 14 }}>
                Der Auftraggeber ist im Bereich der Vermittlung von Kunden für Rückforderungsansprüche im Zusammenhang mit unzulässigen Bearbeitungsgebühren bei Finanzierungen tätig.
              </p>
              <p style={{ marginBottom: 14 }}>
                Der Vertriebspartner vermittelt dem Auftraggeber Kunden, die ihre Ansprüche prüfen und gegebenenfalls durchsetzen lassen möchten.
              </p>

              <h4 style={{ fontWeight: 'bold', marginTop: 16, marginBottom: 8 }}>§ 2 Rechtsstellung des Vertriebspartners</h4>
              <p style={{ marginBottom: 14 }}>
                Der Vertriebspartner handelt als selbstständiger Unternehmer.
              </p>
              <p style={{ marginBottom: 14 }}>
                Es besteht kein Arbeitsverhältnis, kein Handelsvertreterverhältnis und keine gesellschaftsrechtliche Verbindung.
              </p>
              <p style={{ marginBottom: 14 }}>
                Der Vertriebspartner ist nicht berechtigt, den Auftraggeber rechtsgeschäftlich zu vertreten oder verbindliche Zusagen abzugeben.
              </p>

              <h4 style={{ fontWeight: 'bold', marginTop: 16, marginBottom: 8 }}>§ 3 Vertriebsstruktur und Anbindung</h4>
              <p style={{ marginBottom: 14 }}>
                Der Auftraggeber verfügt über eine exklusive bzw. vorrangige Vertriebsanbindung bei der Klagekraft GmbH im Bereich der Vermittlung von Kunden für die Durchsetzung von Rückforderungsansprüchen. Der Auftraggeber wurde im Rahmen der bestehenden Vertriebsstruktur zusätzlich mit der operativen Betreuung, Einarbeitung sowie laufenden Unterstützung externer Partner der Klagekraft GmbH betraut.
              </p>
              <p style={{ marginBottom: 14 }}>
                Der Vertriebspartner nimmt zur Kenntnis, dass eine direkte Anbindung an die Klagekraft GmbH oder sonstige vom Auftraggeber eingesetzte Kooperationspartner nicht vorgesehen ist.
              </p>
              <p style={{ marginBottom: 14 }}>
                Sämtliche durch den Vertriebspartner vermittelten Geschäftsabschlüsse werden ausschließlich über den Auftraggeber abgewickelt.
              </p>

              <h4 style={{ fontWeight: 'bold', marginTop: 16, marginBottom: 8 }}>§ 4 Pflichten des Vertriebspartners</h4>
              <p style={{ marginBottom: 10 }}>Der Vertriebspartner verpflichtet sich:</p>
              <ul style={{ paddingLeft: 20, marginBottom: 14, listStyleType: 'disc' }}>
                <li style={{ marginBottom: 6 }}>Kunden sachlich, korrekt und vollständig zu informieren</li>
                <li style={{ marginBottom: 6 }}>ausschließlich vollständig vorbereitete Fälle zu übermitteln</li>
              </ul>
              <p style={{ marginBottom: 10 }}>Ein vollständiger Fall liegt insbesondere vor, wenn folgende Unterlagen vorliegen:</p>
              <ul style={{ paddingLeft: 20, marginBottom: 14, listStyleType: 'disc' }}>
                <li style={{ marginBottom: 6 }}>unterzeichneter Vertrag zur Anspruchsdurchsetzung</li>
                <li style={{ marginBottom: 6 }}>vollständige Kreditunterlagen</li>
                <li style={{ marginBottom: 6 }}>Kopie eines gültigen amtlichen Lichtbildausweises</li>
              </ul>

              <h4 style={{ fontWeight: 'bold', marginTop: 16, marginBottom: 8 }}>§ 5 Annahme von Fällen</h4>
              <p style={{ marginBottom: 14 }}>
                Der Auftraggeber ist berechtigt, vermittelte Fälle nach eigenem Ermessen anzunehmen oder abzulehnen.
              </p>
              <p style={{ marginBottom: 14 }}>
                Ein Provisionsanspruch entsteht ausschließlich für angenommene und erfolgreich abgewickelte Fälle.
              </p>

              <h4 style={{ fontWeight: 'bold', marginTop: 16, marginBottom: 8 }}>§ 6 Vergütung</h4>
              <p style={{ marginBottom: 14 }}>
                Die Vergütung des Vertriebspartners ist erfolgsabhängig.
              </p>
              <p style={{ marginBottom: 14 }}>
                Der Vertriebspartner erhält im Erfolgsfall eine Provision in Höhe von:<br />
                <strong>{partner.commissionPercent}% der vom Prozessfinanzierer vereinnahmten Erfolgsbeteiligung (35,5 % des Rückflusses)</strong>.
              </p>
              <p style={{ marginBottom: 14 }}>
                Die Bemessungsgrundlage ist ausschließlich der tatsächlich vereinnahmte Betrag.
              </p>

              <h4 style={{ fontWeight: 'bold', marginTop: 16, marginBottom: 8 }}>§ 7 Abrechnung und Auszahlung</h4>
              <p style={{ marginBottom: 14 }}>
                Die Auszahlung der Provision erfolgt einmal pro Woche, jeweils Donnerstags nach Abrechnung, spätestens jedoch drei Tage nach Eingang der jeweiligen Zahlung seitens der Bank.
              </p>

              <h4 style={{ fontWeight: 'bold', marginTop: 16, marginBottom: 8 }}>§ 8 Haftung und Freistellung</h4>
              <p style={{ marginBottom: 14 }}>
                Der Vertriebspartner haftet für Schäden, die aus unrichtigen oder unvollständigen Angaben gegenüber Kunden entstehen.
              </p>
              <p style={{ marginBottom: 14 }}>
                Er hält den Auftraggeber von sämtlichen Ansprüchen Dritter frei, die aus vertragswidrigem Verhalten resultieren.
              </p>

              <h4 style={{ fontWeight: 'bold', marginTop: 16, marginBottom: 8 }}>§ 9 Verschwiegenheit und Datenschutz</h4>
              <p style={{ marginBottom: 14 }}>
                Der Vertriebspartner verpflichtet sich zur strikten Verschwiegenheit über alle Geschäfts- und Betriebsgeheimnisse.
              </p>
              <p style={{ marginBottom: 14 }}>
                Die geltenden Datenschutzbestimmungen (insbesondere DSGVO) sind einzuhalten.
              </p>

              <h4 style={{ fontWeight: 'bold', marginTop: 16, marginBottom: 8 }}>§ 10 Vertragsdauer und Kündigung</h4>
              <p style={{ marginBottom: 14 }}>
                Der Vertrag wird auf unbestimmte Zeit abgeschlossen.
              </p>
              <p style={{ marginBottom: 14 }}>
                Er kann von beiden Parteien unter Einhaltung einer Kündigungsfrist von einem Monat zum Monatsende schriftlich gekündigt werden.
              </p>
              <p style={{ marginBottom: 14 }}>
                Das Recht zur fristlosen Kündigung aus wichtigem Grund bleibt unberührt.
              </p>

              <h4 style={{ fontWeight: 'bold', marginTop: 16, marginBottom: 8 }}>§ 11 Wettbewerbsverbot</h4>
              <p style={{ marginBottom: 14 }}>
                Während der Vertragslaufzeit verpflichtet sich der Vertriebspartner, keine unmittelbar konkurrierenden Modelle im Bereich Prozessfinanzierung bzw. Rückforderung von Bearbeitungsgebühren zu vermitteln.
              </p>

              <h4 style={{ fontWeight: 'bold', marginTop: 16, marginBottom: 8 }}>§ 12 Schlussbestimmungen</h4>
              <p style={{ marginBottom: 14 }}>
                Änderungen und Ergänzungen dieses Vertrages bedürfen der Schriftform.
              </p>
              <p style={{ marginBottom: 14 }}>
                Sollten einzelne Bestimmungen unwirksam sein, bleibt der Vertrag im Übrigen unberührt.
              </p>
              <p style={{ marginBottom: 14 }}>
                Es gilt österreichisches Recht.
              </p>
              <p style={{ marginBottom: 20 }}>
                Gerichtsstand ist – soweit gesetzlich zulässig – Wien.
              </p>

              <hr style={{ border: 0, borderTop: '1px solid var(--gray-200)', margin: '20px 0' }} />
              
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px', fontSize: '0.8rem', marginTop: 20 }}>
                <div>
                  <strong>Auftraggeber:</strong><br />
                  Krist & Partner GmbH<br />
                  Wien, am {new Date().toLocaleDateString('de-AT')}
                </div>
                <div>
                  <strong>Vertriebspartner:</strong><br />
                  {partner.partnerType === 'company' && partner.companyName ? (
                    <>
                      {partner.companyName}<br />
                      i.V. {partner.firstName} {partner.lastName}
                    </>
                  ) : (
                    <>{partner.firstName} {partner.lastName}</>
                  )}<br />
                  {partner.city || 'Wien'}, am {new Date().toLocaleDateString('de-AT')}
                </div>
              </div>
            </div>
          </div>

          {/* Section 3: Signature Canvas */}
          <div style={{ marginBottom: 24 }}>
            <label style={{ display: 'block', fontWeight: 600, fontSize: '0.85rem', color: 'var(--gray-600)' }}>
              Digitale Unterschrift *
            </label>
            <SignaturePad onChange={(sig) => setSignature(sig)} />
          </div>

          {/* Section 4: Password Settings */}
          <div className="form-group" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div>
              <label>Passwort festlegen *</label>
              <input
                required
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
              />
            </div>
            <div>
              <label>Passwort bestätigen *</label>
              <input
                required
                type="password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                placeholder="••••••••"
              />
            </div>
          </div>

          <div style={{ marginTop: 24 }}>
            <button type="submit" className="btn btn-primary" style={{ width: '100%', padding: '14px', fontSize: '1rem' }} disabled={signing}>
              {signing ? 'Registrierung wird verarbeitet...' : 'Vertrag unterzeichnen & registrieren'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
