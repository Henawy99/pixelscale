import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export async function POST(
  request: Request,
  props: { params: Promise<{ id: string }> }
) {
  const params = await props.params;
  const { id } = params;

  try {
    const { authUserId, signature } = await request.json();

    if (!signature) {
      return NextResponse.json(
        { error: 'Missing required parameter: signature' },
        { status: 400 }
      );
    }

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://placeholder-project.supabase.co';
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'placeholder-key';

    const supabase = createClient(supabaseUrl, serviceKey);

    let finalAuthUserId = authUserId;

    // If authUserId was not provided (e.g. user already exists and signUp failed to return user id),
    // resolve it by fetching the partner's email and matching against auth.users list.
    if (!finalAuthUserId) {
      const { data: partnerData, error: partnerError } = await supabase
        .from('partners')
        .select('email')
        .eq('id', id)
        .single();

      if (partnerError || !partnerData?.email) {
        return NextResponse.json(
          { error: `Could not retrieve partner email: ${partnerError?.message || 'Not found'}` },
          { status: 404 }
        );
      }

      const { data: usersData, error: listError } = await supabase.auth.admin.listUsers();
      if (listError) {
        return NextResponse.json(
          { error: `Failed to retrieve auth users: ${listError.message}` },
          { status: 500 }
        );
      }

      const matchedUser = usersData?.users.find(
        (u) => u.email?.toLowerCase().trim() === partnerData.email.toLowerCase().trim()
      );

      if (!matchedUser) {
        return NextResponse.json(
          { error: 'User does not exist in Supabase Auth. Please complete sign-up first.' },
          { status: 400 }
        );
      }

      finalAuthUserId = matchedUser.id;
    }

    const { data, error } = await supabase
      .from('partners')
      .update({
        auth_user_id: finalAuthUserId,
        status: 'active',
        contract_signed_at: new Date().toISOString(),
        contract_signature_data: signature,
      })
      .eq('id', id)
      .select();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true, data });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
