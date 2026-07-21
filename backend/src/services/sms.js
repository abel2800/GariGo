/**
 * SMS provider abstraction.
 * SMS_PROVIDER=console (default) | twilio | ethio_telecom
 */
export async function sendSms(phone, message) {
  const provider = process.env.SMS_PROVIDER || 'console';

  if (provider === 'console') {
    console.log(`[SMS:${provider}] → ${phone}: ${message}`);
    return { ok: true, provider, stub: true };
  }

  if (provider === 'twilio') {
    const sid = process.env.TWILIO_ACCOUNT_SID;
    const token = process.env.TWILIO_AUTH_TOKEN;
    const from = process.env.TWILIO_FROM;
    if (!sid || !token || !from) {
      throw new Error('Twilio credentials missing');
    }
    const auth = Buffer.from(`${sid}:${token}`).toString('base64');
    const body = new URLSearchParams({ To: phone, From: from, Body: message });
    const res = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`,
      {
        method: 'POST',
        headers: {
          Authorization: `Basic ${auth}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body,
      },
    );
    if (!res.ok) throw new Error(`Twilio SMS failed: ${await res.text()}`);
    return { ok: true, provider };
  }

  // Ethio Telecom / local aggregator — plug real endpoint when contracted
  if (provider === 'ethio_telecom') {
    const key = process.env.SMS_API_KEY;
    const sender = process.env.SMS_SENDER_ID || 'GariGo';
    if (!key) throw new Error('SMS_API_KEY missing');
    console.log(`[SMS:ethio_telecom stub] ${sender} → ${phone}: ${message}`);
    return { ok: true, provider, stub: true };
  }

  throw new Error(`Unknown SMS_PROVIDER: ${provider}`);
}

export function generateOtp() {
  // Always 123456 in development for easy testing unless FORCE_RANDOM_OTP=1
  if (process.env.NODE_ENV !== 'production' && process.env.FORCE_RANDOM_OTP !== '1') {
    return '123456';
  }
  return String(Math.floor(100000 + Math.random() * 900000));
}
