import type { APIRoute } from 'astro';

export const prerender = false;

const JSON_HEADERS = { 'Content-Type': 'application/json' };

export const POST: APIRoute = async ({ request }) => {
  const formData = await request.formData();
  const email = formData.get('email')?.toString().trim() ?? '';

  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return new Response(JSON.stringify({ error: 'A valid email address is required.' }), {
      status: 400,
      headers: JSON_HEADERS,
    });
  }

  const apiKey = process.env.BUTTONDOWN_API_KEY;
  if (!apiKey) {
    return new Response(JSON.stringify({ error: 'Newsletter service is not configured.' }), {
      status: 500,
      headers: JSON_HEADERS,
    });
  }

  try {
    const resp = await fetch('https://api.buttondown.email/v1/subscribers', {
      method: 'POST',
      headers: {
        Authorization: `Token ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ email_address: email }),
      signal: AbortSignal.timeout(10000),
    });

    if (!resp.ok) {
      const body = await resp.json().catch(() => ({}));
      const msg = (body.detail ?? '').toLowerCase();

      if (msg.includes('already') || msg.includes('subscribed')) {
        return new Response(JSON.stringify({ error: 'You are already subscribed.' }), {
          status: 409,
          headers: JSON_HEADERS,
        });
      }

      throw new Error(body.detail ?? `Buttondown error ${resp.status}`);
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: JSON_HEADERS,
    });
  } catch (err) {
    console.error('[subscribe] request failed', err);
    return new Response(JSON.stringify({ error: 'Something went wrong. Please try again.' }), {
      status: 500,
      headers: JSON_HEADERS,
    });
  }
};
