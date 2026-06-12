'use client';

import { use, useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';

interface PartnerData {
  id: string;
  first_name: string;
  last_name: string;
  email: string;
  birth_date: string;
  street: string;
  postal_code: string;
  city: string;
  partner_type: string;
  company_name?: string;
  company_address?: string;
  commission_percent: number;
  contract_signed_at?: string;
  contract_signature_data?: string;
}

interface PageProps {
  params: Promise<{ id: string }>;
}

export default function PartnerContractPDF({ params }: PageProps) {
  const resolvedParams = use(params);
  const partnerId = resolvedParams.id;
  const router = useRouter();

  const [loading, setLoading] = useState(true);
  const [partner, setPartner] = useState<PartnerData | null>(null);

  useEffect(() => {
    async function fetchPartner() {
      try {
        const res = await fetch(`/api/partner/${partnerId}`);
        if (res.ok) {
          const data = await res.json();
          setPartner(data);
        }
      } catch (err) {
        console.error('Failed to load partner details:', err);
      } finally {
        setLoading(false);
      }
    }
    fetchPartner();
  }, [partnerId]);

  if (loading) {
    return (
      <div style={{ padding: '40px', fontFamily: 'sans-serif', textAlign: 'center' }}>
        Lade Vertragsdaten...
      </div>
    );
  }

  if (!partner) {
    return (
      <div style={{ padding: '40px', fontFamily: 'sans-serif', textAlign: 'center', color: 'red' }}>
        Kooperationsvereinbarung konnte nicht gefunden werden.
      </div>
    );
  }

  const signedDateStr = partner.contract_signed_at
    ? new Date(partner.contract_signed_at).toLocaleDateString('de-AT')
    : new Date().toLocaleDateString('de-AT');

  return (
    <div style={{ background: '#f8fafc', minHeight: '100vh', padding: '40px 20px', fontFamily: 'sans-serif' }}>
      {/* Header controls (hidden on print) */}
      <div className="no-print" style={{
        maxWidth: '800px',
        margin: '0 auto 20px auto',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        background: 'white',
        padding: '16px 24px',
        borderRadius: '8px',
        boxShadow: '0 1px 3px rgba(0,0,0,0.1)'
      }}>
        <div>
          <h4 style={{ margin: 0, color: '#0A1628' }}>Partnervertrag: {partner.first_name} {partner.last_name}</h4>
          <p style={{ margin: '4px 0 0 0', fontSize: '0.8rem', color: '#64748b' }}>
            Status: {partner.contract_signed_at ? `Unterzeichnet am ${new Date(partner.contract_signed_at).toLocaleString('de-AT')}` : 'Nicht unterzeichnet'}
          </p>
        </div>
        <div style={{ display: 'flex', gap: '10px' }}>
          <button
            onClick={() => window.print()}
            style={{
              background: '#00B4D8',
              color: 'white',
              border: 'none',
              padding: '10px 18px',
              borderRadius: '6px',
              fontWeight: 600,
              fontSize: '0.85rem',
              cursor: 'pointer'
            }}
          >
            🖨️ Als PDF speichern / drucken
          </button>
          <button
            onClick={() => router.back()}
            style={{
              background: 'transparent',
              border: '1px solid #cbd5e1',
              color: '#475569',
              padding: '10px 18px',
              borderRadius: '6px',
              fontWeight: 600,
              fontSize: '0.85rem',
              cursor: 'pointer'
            }}
          >
            Zurück
          </button>
        </div>
      </div>

      {/* Contract Layout */}
      <div className="print-area" style={{
        maxWidth: '800px',
        margin: '0 auto',
        background: 'white',
        padding: '60px 50px',
        boxShadow: '0 4px 6px -1px rgba(0,0,0,0.1), 0 2px 4px -1px rgba(0,0,0,0.06)',
        borderRadius: '8px',
        color: '#1e293b',
        lineHeight: '1.6',
        fontSize: '0.9rem'
      }}>
        <h3 style={{ fontSize: '1.25rem', fontWeight: 'bold', textAlign: 'center', marginBottom: '30px', color: '#0A1628' }}>
          VERTRIEBSVEREINBARUNG FÜR PROZESSFINANZIERUNG
        </h3>
        
        <p style={{ marginBottom: '20px' }}>
          zwischen<br />
          <strong>Krist & Partner GmbH</strong><br />
          Faradaygasse 6<br />
          1030 Wien<br />
          – nachfolgend „Auftraggeber“ –
        </p>
        
        <p style={{ marginBottom: '20px' }}>
          und<br />
          {partner.partner_type === 'company' ? (
            <>
              <strong>{partner.company_name}</strong><br />
              {partner.company_address}<br />
              {partner.first_name && partner.last_name ? `vertreten durch ${partner.first_name} ${partner.last_name}` : ''}<br />
            </>
          ) : (
            <>
              <strong>{partner.first_name} {partner.last_name}</strong><br />
              {partner.street ? `${partner.street}, ` : ''}{partner.postal_code} {partner.city}<br />
            </>
          )}
          – nachfolgend „Vertriebspartner“ –
        </p>
        
        <p style={{ marginBottom: '30px' }}>
          gemeinsam „Vertragsparteien“.
        </p>

        <h4 style={{ fontWeight: 'bold', marginTop: '24px', marginBottom: '8px' }}>§ 1 Vertragsgegenstand</h4>
        <p style={{ marginBottom: '16px' }}>
          Der Auftraggeber ist im Bereich der Vermittlung von Kunden für Rückforderungsansprüche im Zusammenhang mit unzulässigen Bearbeitungsgebühren bei Finanzierungen tätig.
        </p>
        <p style={{ marginBottom: '16px' }}>
          Der Vertriebspartner vermittelt dem Auftraggeber Kunden, die ihre Ansprüche prüfen und gegebenenfalls durchsetzen lassen möchten.
        </p>

        <h4 style={{ fontWeight: 'bold', marginTop: '24px', marginBottom: '8px' }}>§ 2 Rechtsstellung des Vertriebspartners</h4>
        <p style={{ marginBottom: '16px' }}>
          Der Vertriebspartner handelt als selbstständiger Unternehmer.
        </p>
        <p style={{ marginBottom: '16px' }}>
          Es besteht kein Arbeitsverhältnis, kein Handelsvertreterverhältnis und keine gesellschaftsrechtliche Verbindung.
        </p>
        <p style={{ marginBottom: '16px' }}>
          Der Vertriebspartner ist nicht berechtigt, den Auftraggeber rechtsgeschäftlich zu vertreten oder verbindliche Zusagen abzugeben.
        </p>

        <h4 style={{ fontWeight: 'bold', marginTop: '24px', marginBottom: '8px' }}>§ 3 Vertriebsstruktur und Anbindung</h4>
        <p style={{ marginBottom: '16px' }}>
          Der Auftraggeber verfügt über eine exklusive bzw. vorrangige Vertriebsanbindung bei der Klagekraft GmbH im Bereich der Vermittlung von Kunden für die Durchsetzung von Rückforderungsansprüchen. Der Auftraggeber wurde im Rahmen der bestehenden Vertriebsstruktur zusätzlich mit der operativen Betreuung, Einarbeitung sowie laufenden Unterstützung externer Partner der Klagekraft GmbH betraut.
        </p>
        <p style={{ marginBottom: '16px' }}>
          Der Vertriebspartner nimmt zur Kenntnis, dass eine direkte Anbindung an die Klagekraft GmbH oder sonstige vom Auftraggeber eingesetzte Kooperationspartner nicht vorgesehen ist.
        </p>
        <p style={{ marginBottom: '16px' }}>
          Sämtliche durch den Vertriebspartner vermittelten Geschäftsabschlüsse werden ausschließlich über den Auftraggeber abgewickelt.
        </p>

        <h4 style={{ fontWeight: 'bold', marginTop: '24px', marginBottom: '8px' }}>§ 4 Pflichten des Vertriebspartners</h4>
        <p style={{ marginBottom: '10px' }}>Der Vertriebspartner verpflichtet sich:</p>
        <ul style={{ paddingLeft: '20px', marginBottom: '16px', listStyleType: 'disc' }}>
          <li style={{ marginBottom: '6px' }}>Kunden sachlich, korrekt und vollständig zu informieren</li>
          <li style={{ marginBottom: '6px' }}>ausschließlich vollständig vorbereitete Fälle zu übermitteln</li>
        </ul>
        <p style={{ marginBottom: '10px' }}>Ein vollständiger Fall liegt insbesondere vor, wenn folgende Unterlagen vorliegen:</p>
        <ul style={{ paddingLeft: '20px', marginBottom: '16px', listStyleType: 'disc' }}>
          <li style={{ marginBottom: '6px' }}>unterzeichneter Vertrag zur Anspruchsdurchsetzung</li>
          <li style={{ marginBottom: '6px' }}>vollständige Kreditunterlagen</li>
          <li style={{ marginBottom: '6px' }}>Kopie eines gültigen amtlichen Lichtbildausweises</li>
        </ul>

        <h4 style={{ fontWeight: 'bold', marginTop: '24px', marginBottom: '8px' }}>§ 5 Annahme von Fällen</h4>
        <p style={{ marginBottom: '16px' }}>
          Der Auftraggeber ist berechtigt, vermittelte Fälle nach eigenem Ermessen anzunehmen oder abzulehnen.
        </p>
        <p style={{ marginBottom: '16px' }}>
          Ein Provisionsanspruch entsteht ausschließlich für angenommene und erfolgreich abgewickelte Fälle.
        </p>

        <h4 style={{ fontWeight: 'bold', marginTop: '24px', marginBottom: '8px' }}>§ 6 Vergütung</h4>
        <p style={{ marginBottom: '16px' }}>
          Die Vergütung des Vertriebspartners ist erfolgsabhängig.
        </p>
        <p style={{ marginBottom: '16px' }}>
          Der Vertriebspartner erhält im Erfolgsfall eine Provision in Höhe von:<br />
          <strong>{partner.commission_percent}% der vom Prozessfinanzierer vereinnahmten Erfolgsbeteiligung (35,5 % des Rückflusses)</strong>.
        </p>
        <p style={{ marginBottom: '16px' }}>
          Die Bemessungsgrundlage ist ausschließlich der tatsächlich vereinnahmte Betrag.
        </p>

        <h4 style={{ fontWeight: 'bold', marginTop: '24px', marginBottom: '8px' }}>§ 7 Abrechnung und Auszahlung</h4>
        <p style={{ marginBottom: '16px' }}>
          Die Auszahlung der Provision erfolgt einmal pro Woche, jeweils Donnerstags nach Abrechnung, spätestens jedoch drei Tage nach Eingang der jeweiligen Zahlung seitens der Bank.
        </p>

        <h4 style={{ fontWeight: 'bold', marginTop: '24px', marginBottom: '8px' }}>§ 8 Haftung und Freistellung</h4>
        <p style={{ marginBottom: '16px' }}>
          Der Vertriebspartner haftet für Schäden, die aus unrichtigen oder unvollständigen Angaben gegenüber Kunden entstehen.
        </p>
        <p style={{ marginBottom: '16px' }}>
          Er hält den Auftraggeber von sämtlichen Ansprüchen Dritter frei, die aus vertragswidrigem Verhalten resultieren.
        </p>

        <h4 style={{ fontWeight: 'bold', marginTop: '24px', marginBottom: '8px' }}>§ 9 Verschwiegenheit und Datenschutz</h4>
        <p style={{ marginBottom: '16px' }}>
          Der Vertriebspartner verpflichtet sich zur strikten Verschwiegenheit über alle Geschäfts- und Betriebsgeheimnisse.
        </p>
        <p style={{ marginBottom: '16px' }}>
          Die geltenden Datenschutzbestimmungen (insbesondere DSGVO) sind einzuhalten.
        </p>

        <h4 style={{ fontWeight: 'bold', marginTop: '24px', marginBottom: '8px' }}>§ 10 Vertragsdauer und Kündigung</h4>
        <p style={{ marginBottom: '16px' }}>
          Der Vertrag wird auf unbestimmte Zeit abgeschlossen.
        </p>
        <p style={{ marginBottom: '16px' }}>
          Er kann von beiden Parteien unter Einhaltung einer Kündigungsfrist von einem Monat zum Monatsende schriftlich gekündigt werden.
        </p>
        <p style={{ marginBottom: '16px' }}>
          Das Recht zur fristlosen Kündigung aus wichtigem Grund bleibt unberührt.
        </p>

        <h4 style={{ fontWeight: 'bold', marginTop: '24px', marginBottom: '8px' }}>§ 11 Wettbewerbsverbot</h4>
        <p style={{ marginBottom: '16px' }}>
          Während der Vertragslaufzeit verpflichtet sich der Vertriebspartner, keine unmittelbar konkurrierenden Modelle im Bereich Prozessfinanzierung bzw. Rückforderung von Bearbeitungsgebühren zu vermitteln.
        </p>

        <h4 style={{ fontWeight: 'bold', marginTop: '24px', marginBottom: '8px' }}>§ 12 Schlussbestimmungen</h4>
        <p style={{ marginBottom: '16px' }}>
          Änderungen und Ergänzungen dieses Vertrages bedürfen der Schriftform.
        </p>
        <p style={{ marginBottom: '16px' }}>
          Sollten einzelne Bestimmungen unwirksam sein, bleibt der Vertrag im Übrigen unberührt.
        </p>
        <p style={{ marginBottom: '16px' }}>
          Es gilt österreichisches Recht.
        </p>
        <p style={{ marginBottom: '30px' }}>
          Gerichtsstand ist – soweit gesetzlich zulässig – Wien.
        </p>

        <hr style={{ border: 0, borderTop: '1px solid #cbd5e1', margin: '30px 0' }} />
        
        {/* Signatures */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '40px', marginTop: '20px' }}>
          <div>
            <strong>Auftraggeber:</strong><br />
            Krist & Partner GmbH<br />
            Wien, am {signedDateStr}
            <div style={{ marginTop: '20px', height: '60px', borderBottom: '1px solid #94a3b8', fontStyle: 'italic', display: 'flex', alignItems: 'center' }}>
              Krist & Partner GmbH
            </div>
          </div>
          <div>
            <strong>Vertriebspartner:</strong><br />
            {partner.partner_type === 'company' && partner.company_name ? (
              <>
                {partner.company_name}<br />
                i.V. {partner.first_name} {partner.last_name}
              </>
            ) : (
              <>{partner.first_name} {partner.last_name}</>
            )}<br />
            {partner.city || 'Wien'}, am {signedDateStr}
            
            {partner.contract_signature_data ? (
              <div style={{ marginTop: '10px', height: '70px', display: 'flex', alignItems: 'flex-end' }}>
                <img
                  src={partner.contract_signature_data}
                  alt="Signature"
                  style={{ maxHeight: '60px', maxWidth: '100%', objectFit: 'contain' }}
                />
              </div>
            ) : (
              <div style={{ marginTop: '20px', height: '60px', borderBottom: '1px solid #94a3b8', display: 'flex', alignItems: 'center', color: '#94a3b8', fontSize: '0.8rem' }}>
                Ausstehende Unterschrift
              </div>
            )}
          </div>
        </div>
      </div>

      <style jsx global>{`
        @media print {
          body {
            background: white !important;
            padding: 0 !important;
          }
          .no-print {
            display: none !important;
          }
          .print-area {
            box-shadow: none !important;
            padding: 0 !important;
            margin: 0 !important;
            max-width: 100% !important;
          }
        }
      `}</style>
    </div>
  );
}
