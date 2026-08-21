import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Escape values that get interpolated into the email HTML so a user cannot inject
// markup/links into a message sent from our trusted sending domain. [Fixes #3]
const escapeHtml = (value: unknown): string =>
  String(value ?? '').replace(/[&<>"']/g, (c) => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c] as string
  ))

// Keep the subject on a single line and bounded, so it can't be abused for spoofing.
const sanitizeSubject = (value: unknown): string =>
  String(value ?? '').replace(/[\r\n]+/g, ' ').trim().slice(0, 120)

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

serve(async (req) => {
  if (req.method === 'OPTIONS') { return new Response('ok', { headers: corsHeaders }) }

  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  try {
    // --- 1. Identify the BUYER from the verified JWT, never from the body. [Fixes #2] ---
    // verify_jwt = true guarantees a token is present; we derive identity from it so the
    // client cannot spoof who the message is "from".
    const jwt = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '')
    const { data: { user: buyer }, error: buyerError } = await supabaseAdmin.auth.getUser(jwt)
    if (buyerError || !buyer?.email) {
      return json({ ok: false, error: 'Not authenticated.' }, 401)
    }
    const buyerId = buyer.id
    const buyerEmail = buyer.email

    // --- 2. Resolve the SELLER + title server-side. -----------------------------------
    // Preferred path: the client sends listingId and we look the listing up authoritatively.
    // Legacy path: older app builds still send sellerId/itemTitle in the body; we tolerate
    // that so installs in the wild keep working, but the buyer identity above is always
    // taken from the JWT regardless.
    const body = await req.json().catch(() => ({}))
    const { listingId, message } = body
    let sellerId: string | undefined = body.sellerId
    let itemTitle: string = body.itemTitle ?? ''

    if (listingId) {
      const { data: listing, error: listingError } = await supabaseAdmin
        .from('listings')
        .select('user_id, title')
        .eq('id', listingId)
        .single()
      if (listingError || !listing) {
        return json({ ok: false, error: 'Listing not found.' }, 404)
      }
      sellerId = listing.user_id
      itemTitle = listing.title ?? ''
    }

    if (!sellerId) {
      return json({ ok: false, error: 'Missing listing reference.' }, 400)
    }
    if (sellerId === buyerId) {
      return json({ ok: false, error: 'You cannot message your own listing.' }, 400)
    }

    // --- 3. Look up the seller's email + the buyer's display name. ---------------------
    const { data: { user: seller }, error: sellerError } = await supabaseAdmin.auth.admin.getUserById(sellerId)
    if (sellerError || !seller?.email) {
      return json({ ok: false, error: 'Seller unavailable.' }, 404)
    }
    const sellerEmail = seller.email

    // Look the buyer's name up directly by id (no full-table user enumeration). [Fixes #11]
    let buyerName = buyerEmail
    const { data: buyerProfile } = await supabaseAdmin
      .from('profiles')
      .select('full_name')
      .eq('id', buyerId)
      .single()
    if (buyerProfile?.full_name) buyerName = buyerProfile.full_name

    // Pre-escaped values for the HTML template.
    const safeName = escapeHtml(buyerName)
    const safeTitle = escapeHtml(itemTitle)
    const safeMessage = escapeHtml(message)
    const safeEmail = escapeHtml(buyerEmail)

    // --- 4. Send the email via Resend. ------------------------------------------------
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
        subject: sanitizeSubject(`${buyerName} is interested in your listing: ${itemTitle}`),
        html: `
          <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 480px; margin: 0 auto; padding: 40px 24px; background: #ffffff;">
            <div style="text-align: center; margin-bottom: 32px;">
              <h1 style="font-size: 24px; font-weight: 700; color: #1a1a1a; margin: 0;">CampusCloset</h1>
              <p style="color: #888; font-size: 14px; margin: 4px 0 0;">Campus Exchange for Students</p>
            </div>

            <h2 style="font-size: 20px; font-weight: 600; color: #1a1a1a;">A fellow PEA student is interested in your listing!</h2>
            <p style="color: #555; font-size: 15px; line-height: 1.6;">
              <strong>${safeName}</strong> wants to buy your <strong>${safeTitle}</strong>. Here's what they said:
            </p>

            <div style="background: #f5f5f7; border-left: 4px solid #007AFF; border-radius: 6px; padding: 16px 20px; margin: 24px 0;">
              <p style="color: #333; font-size: 15px; margin: 0; line-height: 1.6;">"${safeMessage}"</p>
            </div>

            <div style="text-align: center; margin: 32px 0;">
              <a href="mailto:${safeEmail}" style="background: #007AFF; color: #ffffff; text-decoration: none; padding: 14px 32px; border-radius: 10px; font-size: 16px; font-weight: 600; display: inline-block;">
                Reply to ${safeName}
              </a>
            </div>

            <p style="color: #aaa; font-size: 13px; line-height: 1.5;">
              Replying to this email will send your message directly to ${safeName} at ${safeEmail}.
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

    // Treat a Resend failure as a real failure so the client does not show "Message Sent". [Fixes #12]
    if (!res.ok) {
      const detail = await res.text().catch(() => '')
      console.error('Resend send failed:', res.status, detail)
      return json({ ok: false, error: 'Unable to send message.' }, 502)
    }

    // --- 5. Create both in-app notifications server-side (service role). [Fixes #7] ----
    // These used to be inserted by the client, which allowed writing into any user's feed.
    // Only this trusted function writes notifications now.
    const { error: notifError } = await supabaseAdmin.from('notifications').insert([
      {
        user_id: buyerId,
        type: 'message_sent',
        title: 'Message Sent',
        body: `Your message about '${itemTitle}' was delivered to the seller's email inbox. You'll get a notification here when they reply.`,
      },
      {
        user_id: sellerId,
        type: 'message_received',
        title: 'New Interest in Your Listing',
        body: `${buyerEmail} is interested in your listing '${itemTitle}' and has sent you an email. Reply to connect with them!`,
      },
    ])
    if (notifError) {
      // The email already went out; surface a soft failure but do not 500 the whole call.
      console.error('Notification insert failed:', notifError)
    }

    return json({ ok: true })

  } catch (error) {
    console.error('send-message error:', error)
    return json({ ok: false, error: 'Unable to send message.' }, 500)
  }
})
