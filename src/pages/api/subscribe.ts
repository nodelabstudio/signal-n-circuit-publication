import type { APIRoute } from 'astro';

export const prerender = false;

export const POST: APIRoute = async ({ request }) => {
  const formData = await request.formData();
  const email = formData.get('email')?.toString().trim() ?? '';

  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return new Response(JSON.stringify({ error: 'A valid email address is required.' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const apiKey = process.env.BUTTONDOWN_API_KEY;
  console.log('[subscribe] BUTTONDOWN_API_KEY present:', !!apiKey, '| value:', apiKey ? apiKey.slice(0, 8) + '...' : 'MISSING');
  if (!apiKey) {
    return new Response(JSON.stringify({ error: 'Newsletter service is not configured.', env: Object.keys(process.env).filter(k => k.includes('BUTTON')) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  try {
    const resp = await fetch(`https://api.buttondown.email/v1/subscribers`, {
      method: 'POST',
      headers: {
        Authorization: `Token ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ email_address: email }),
    });

    if (!resp.ok) {
      const body = await resp.json().catch(() => ({}));
      // Buttondown returns 400 with a generic message if already subscribed
      const msg = (body.detail ?? '').toLowerCase();
      if (msg.includes('already') || msg.includes('subscribed')) {
        return new Response(JSON.stringify({ error: 'You are already subscribed.' }), {
          status: 409,
          headers: { 'Content-Type': 'application/json' },
        });
      }
      throw new Error(body.detail ?? `Buttondown error ${resp.status}`);
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('[subscribe]', err);
    return new Response(JSON.stringify({ error: 'Something went wrong. Please try again.' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
};
