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

    // Look up buyer's name from profiles table using their email
    const { data: { users }, error: buyerLookupError } = await supabaseAdmin.auth.admin.listUsers()
    const buyerUser = users?.find(u => u.email === buyerEmail)
    let buyerName = buyerEmail
    if (buyerUser) {
      const { data: profile } = await supabaseAdmin
        .from('profiles')
        .select('full_name')
        .eq('id', buyerUser.id)
        .single()
      if (profile?.full_name) buyerName = profile.full_name
    }

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${Deno.env.get('RESEND_API_KEY')}`
      },
      body: JSON.stringify({
        from: 'CampusCloset <notifications@contact.usecampuscloset.org>',
        to: [sellerEmail],
        reply_to: buyerEmail,
        subject: `${buyerName} is interested in your listing: ${itemTitle}`,
        html: `
          <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 480px; margin: 0 auto; padding: 40px 24px; background: #ffffff;">
            <div style="text-align: center; margin-bottom: 32px;">
              <h1 style="font-size: 24px; font-weight: 700; color: #1a1a1a; margin: 0;">CampusCloset</h1>
              <p style="color: #888; font-size: 14px; margin: 4px 0 0;">Campus Exchange for Students</p>
            </div>

            <h2 style="font-size: 20px; font-weight: 600; color: #1a1a1a;">A fellow PEA student is interested in your listing!</h2>
            <p style="color: #555; font-size: 15px; line-height: 1.6;">
              <strong>${buyerName}</strong> wants to buy your <strong>${itemTitle}</strong>. Here's what they said:
            </p>

            <div style="background: #f5f5f7; border-left: 4px solid #007AFF; border-radius: 6px; padding: 16px 20px; margin: 24px 0;">
              <p style="color: #333; font-size: 15px; margin: 0; line-height: 1.6;">"${message}"</p>
            </div>

            <div style="text-align: center; margin: 32px 0;">
              <a href="mailto:${buyerEmail}" style="background: #007AFF; color: #ffffff; text-decoration: none; padding: 14px 32px; border-radius: 10px; font-size: 16px; font-weight: 600; display: inline-block;">
                Reply to ${buyerName}
              </a>
            </div>

            <p style="color: #aaa; font-size: 13px; line-height: 1.5;">
              Replying to this email will send your message directly to ${buyerName} at ${buyerEmail}.
            </p>

            <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;">
            <p style="color: #bbb; font-size: 12px; text-align: center;">
              You're receiving this because someone messaged you through CampusCloset.<br/>
              Campus Closet · contact.usecampuscloset.org
            </p>
          </div>
        `
      })
    })

    const resData = await res.json()
    return new Response(JSON.stringify(resData), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: corsHeaders })
  }
})