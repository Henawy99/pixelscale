import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const email = searchParams.get('email');

  if (!email) {
    return NextResponse.json({ error: 'Email parameter is required' }, { status: 400 });
  }

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://placeholder-project.supabase.co';
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'placeholder-key';
  const supabase = createClient(supabaseUrl, serviceKey);

  try {
    // 1. Fetch all partners to compute the hierarchy in memory
    const { data: allPartners, error: partnersError } = await supabase
      .from('partners')
      .select('id, email, parent_partner_id, created_at, first_name, last_name');

    if (partnersError) throw partnersError;

    const currentPartner = allPartners.find(
      p => p.email.toLowerCase().trim() === email.toLowerCase().trim()
    );

    if (!currentPartner) {
      return NextResponse.json({ error: 'Partner not found' }, { status: 404 });
    }

    const partnerId = currentPartner.id;
    const isAdmin = email.toLowerCase().trim() === 'office@konsumentenretter.at';

    let myLeads: any[] = [];
    let teamLeads: any[] = [];
    let directPartners: any[] = [];
    let allTeamPartners: any[] = [];

    // Helper to get all descendant IDs recursively
    const getDescendantIds = (pid: string): string[] => {
      const ids: string[] = [];
      const children = allPartners.filter(p => p.parent_partner_id === pid);
      children.forEach(child => {
        ids.push(child.id);
        ids.push(...getDescendantIds(child.id));
      });
      return ids;
    };

    if (isAdmin) {
      // Admin sees everything
      const { data: allLeads, error: leadsError } = await supabase
        .from('leads')
        .select('id, ref_partner_id, status, created_at, first_name, last_name, campaign');
      if (leadsError) throw leadsError;

      myLeads = allLeads;
      // For admin, team leads shows all leads as well
      teamLeads = allLeads;

      directPartners = allPartners.filter(p => !p.parent_partner_id && p.id !== '00000000-0000-0000-0000-000000000000');
      allTeamPartners = allPartners.filter(p => p.id !== '00000000-0000-0000-0000-000000000000');
    } else {
      // Regular partner
      const teamIds = getDescendantIds(partnerId);
      const allQueryIds = [partnerId, ...teamIds];

      const { data: leads, error: leadsError } = await supabase
        .from('leads')
        .select('id, ref_partner_id, status, created_at, first_name, last_name, campaign')
        .in('ref_partner_id', allQueryIds);
      if (leadsError) throw leadsError;

      myLeads = leads.filter(l => l.ref_partner_id === partnerId);
      teamLeads = leads.filter(l => l.ref_partner_id !== partnerId);
      directPartners = allPartners.filter(p => p.parent_partner_id === partnerId);
      allTeamPartners = allPartners.filter(p => teamIds.includes(p.id));
    }

    return NextResponse.json({
      partnerId,
      myLeads,
      teamLeads,
      directPartners,
      allTeamPartners
    });
  } catch (err: any) {
    console.error('Dashboard data API error:', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
