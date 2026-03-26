import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') { return new Response('ok', { headers: corsHeaders }) }

  try {
    const { sellerId, buyerEmail, itemTitle, message } = await req.json()

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { data: { user }, error: userError } = await supabaseAdmin.auth.admin.getUserById(sellerId)
    if (userError || !user) throw new Error("Seller not found")
    
    const sellerEmail = user.email

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${Deno.env.get('RESEND_API_KEY')}`
      },
      body: JSON.stringify({
        from: 'CampusCloset <onboarding@resend.dev>',
        to: [sellerEmail], 
        reply_to: buyerEmail,
        subject: `New interest in your item: ${itemTitle}`,
        html: `
          <h2>You have a new message!</h2>
          <p>Someone is interested in buying your <strong>${itemTitle}</strong>.</p>
          <p><strong>Message from Buyer:</strong><br/>"${message}"</p>
          <hr/>
          <p><em>Reply directly to this email to respond to the buyer.</em></p>
        `
      })
    })

    const resData = await res.json()
    return new Response(JSON.stringify(resData), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: corsHeaders })
  }
})