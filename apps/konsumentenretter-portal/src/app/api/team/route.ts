import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export async function GET() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://placeholder-project.supabase.co';
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'placeholder-key';

  const supabase = createClient(supabaseUrl, serviceKey);

  try {
    const { data: partners, error: partnersError } = await supabase
      .from('partners')
      .select('id, first_name, last_name, email, parent_partner_id, commission_percent, status, company_name, company_address, contract_signed_at');

    if (partnersError) {
      return NextResponse.json({ error: partnersError.message }, { status: 500 });
    }

    // Query all leads to compute counts
    const { data: leads, error: leadsError } = await supabase
      .from('leads')
      .select('ref_partner_id');

    if (leadsError) {
      return NextResponse.json({ error: leadsError.message }, { status: 500 });
    }

    // Aggregate counts
    const leadsMap: Record<string, number> = {};
    leads.forEach((l: any) => {
      if (l.ref_partner_id) {
        leadsMap[l.ref_partner_id] = (leadsMap[l.ref_partner_id] || 0) + 1;
      }
    });

    const result = partners.map((p: any) => ({
      ...p,
      leads_count: leadsMap[p.id] || 0
    }));

    return NextResponse.json(result);
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
