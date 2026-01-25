// Follow this setup guide to integrate with Supabase Edge Functions
// 1. Run `supabase functions new send-invoice`
// 2. Overwrite the content of `supabase/functions/send-invoice/index.ts` with this code.
// 3. Set your Resend API Key: `supabase secrets set RESEND_API_KEY=re_123456789`
// 4. Deploy: `supabase functions deploy send-invoice`

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { Resend } from "npm:resend@2.0.0"

const resend = new Resend(Deno.env.get('RESEND_API_KEY'))

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { invoiceData, clientEmail } = await req.json()

        if (!clientEmail) {
            throw new Error('Client email is required')
        }

        // Generate HTML for the email
        const htmlKeyInfo = `
      <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto;">
        <h2>Invoice #${invoiceData.invoiceNumber} from ${invoiceData.agencyName}</h2>
        <p>Dear ${invoiceData.clientName},</p>
        <p>Please find attached your invoice details below.</p>
        
        <div style="background: #f4f4f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <p><strong>Amount Due:</strong> ${invoiceData.grandTotal.toFixed(2)}</p>
          <p><strong>Due Date:</strong> ${invoiceData.dueDate}</p>
          <p><strong>Status:</strong> ${invoiceData.paymentStatus.toUpperCase()}</p>
        </div>

        <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
          <thead>
            <tr style="background: #e4e4e7;">
              <th style="padding: 10px; text-align: left;">Service</th>
              <th style="padding: 10px; text-align: right;">Amount</th>
            </tr>
          </thead>
          <tbody>
            ${invoiceData.services.map((s: any) => `
              <tr>
                <td style="padding: 10px; border-bottom: 1px solid #e4e4e7;">${s.name} (x${s.quantity})</td>
                <td style="padding: 10px; border-bottom: 1px solid #e4e4e7; text-align: right;">${s.amount.toFixed(2)}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>

         <div style="text-align: right; margin-top: 20px;">
            <h3>Total: ${invoiceData.grandTotal.toFixed(2)}</h3>
         </div>

         <hr style="border: none; border-top: 1px solid #e4e4e7; margin: 20px 0;" />
         <p style="color: #71717a; font-size: 12px;">
            ${invoiceData.agencyName} • ${invoiceData.agencyContact || ''}
         </p>
      </div>
    `;

        // Send Email
        // Note: 'onboarding@resend.dev' only works if you are sending TO the email you registered with Resend.
        // For production, you must verify your domain.
        const data = await resend.emails.send({
            from: 'FinanceFlow <onboarding@resend.dev>',
            to: [clientEmail],
            subject: `Invoice #${invoiceData.invoiceNumber} from ${invoiceData.agencyName}`,
            html: htmlKeyInfo,
        })

        return new Response(JSON.stringify(data), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
    }
})
