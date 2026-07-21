/**
 * Card vault — never persist full PAN or CVC.
 * Tokenizes via Stripe when STRIPE_SECRET_KEY is set; otherwise HMAC vault token.
 */
import crypto from 'crypto';

export class CardVaultError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
    this.name = 'CardVaultError';
  }
}

function detectBrand(digits) {
  if (/^4/.test(digits)) return 'visa';
  if (/^5[1-5]/.test(digits) || /^2[2-7]/.test(digits)) return 'mastercard';
  if (/^3[47]/.test(digits)) return 'amex';
  return 'card';
}

function luhnOk(num) {
  let sum = 0;
  let alt = false;
  for (let i = num.length - 1; i >= 0; i--) {
    let n = Number(num[i]);
    if (alt) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    alt = !alt;
  }
  return sum % 10 === 0;
}

function vaultSecret() {
  return (
    process.env.CARD_VAULT_SECRET ||
    process.env.JWT_SECRET ||
    'garigo_card_vault_dev'
  );
}

function fingerprintPan(digits) {
  return crypto
    .createHmac('sha256', vaultSecret())
    .update(`pan:${digits}`)
    .digest('hex');
}

function normalizeYear(year) {
  const y = Number(year);
  return y < 100 ? 2000 + y : y;
}

/**
 * Validate + tokenize a card. Full PAN/CVC leave this function — never returned.
 */
export async function tokenizeCard({
  number,
  expMonth,
  expYear,
  cvc,
  holderName,
}) {
  const digits = String(number || '').replace(/\D/g, '');
  if (digits.length < 13 || digits.length > 19 || !luhnOk(digits)) {
    throw new CardVaultError('Invalid card number');
  }

  const month = Number(expMonth);
  if (!month || month < 1 || month > 12) {
    throw new CardVaultError('Invalid expiry month');
  }

  const fullYear = normalizeYear(expYear);
  const now = new Date();
  if (
    fullYear < now.getFullYear() ||
    (fullYear === now.getFullYear() && month < now.getMonth() + 1)
  ) {
    throw new CardVaultError('Card is expired');
  }

  const cvcDigits = String(cvc || '').replace(/\D/g, '');
  const brand = detectBrand(digits);
  const cvcLen = brand === 'amex' ? 4 : 3;
  if (cvcDigits.length < cvcLen) {
    throw new CardVaultError('Invalid CVC');
  }

  const name = String(holderName || '').trim();
  if (name.length < 2) {
    throw new CardVaultError('Cardholder name required');
  }

  const last4 = digits.slice(-4);
  const fingerprint = fingerprintPan(digits);

  // Prefer Stripe PaymentMethods when live keys are configured
  if (process.env.STRIPE_SECRET_KEY) {
    const stripe = await tokenizeWithStripe({
      digits,
      month,
      fullYear,
      cvc: cvcDigits,
      name,
    });
    return {
      brand: stripe.brand || brand,
      last4: stripe.last4 || last4,
      expMonth: month,
      expYear: fullYear,
      holderName: name,
      provider: 'stripe',
      providerToken: stripe.paymentMethodId,
      fingerprint,
    };
  }

  // Local vault token — deterministic so the same card can't be added twice
  const providerToken = `vault_v1_${fingerprint}`;

  return {
    brand,
    last4,
    expMonth: month,
    expYear: fullYear,
    holderName: name,
    provider: 'garigo_vault',
    providerToken,
    fingerprint,
  };
}

async function tokenizeWithStripe({ digits, month, fullYear, cvc, name }) {
  const body = new URLSearchParams();
  body.set('type', 'card');
  body.set('card[number]', digits);
  body.set('card[exp_month]', String(month));
  body.set('card[exp_year]', String(fullYear));
  body.set('card[cvc]', cvc);
  body.set('billing_details[name]', name);

  const res = await fetch('https://api.stripe.com/v1/payment_methods', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.STRIPE_SECRET_KEY}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body,
  });

  const data = await res.json();
  if (!res.ok) {
    const msg =
      data?.error?.message || 'Card was declined by the payment provider';
    throw new CardVaultError(msg, 402);
  }

  return {
    paymentMethodId: data.id,
    brand: data.card?.brand,
    last4: data.card?.last4,
  };
}

/**
 * Charge a previously tokenized card (Stripe) or init Chapa checkout.
 */
export async function chargeSavedCard({
  providerToken,
  amount,
  reference,
  currency = 'etb',
}) {
  const birr = Math.round(Number(amount));

  if (
    process.env.STRIPE_SECRET_KEY &&
    String(providerToken).startsWith('pm_')
  ) {
    // ETB is a zero-decimal currency on Stripe
    const body = new URLSearchParams();
    body.set('amount', String(birr));
    body.set('currency', currency);
    body.set('confirm', 'true');
    body.set('payment_method', providerToken);
    body.set('description', `GariGo trip ${reference}`);
    body.set('metadata[reference]', String(reference));

    const res = await fetch('https://api.stripe.com/v1/payment_intents', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.STRIPE_SECRET_KEY}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body,
    });
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data?.error?.message || 'Card charge failed');
    }
    return {
      ok: true,
      providerTxnId: data.id,
      status: data.status === 'succeeded' ? 'paid' : data.status,
      stub: false,
      provider: 'stripe',
    };
  }

  if (process.env.CHAPA_SECRET_KEY) {
    const txRef = `garigo-card-${reference}-${Date.now()}`;
    const res = await fetch('https://api.chapa.co/v1/transaction/initialize', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.CHAPA_SECRET_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        amount: String(birr),
        currency: 'ETB',
        tx_ref: txRef,
        email: process.env.CHAPA_MERCHANT_EMAIL || 'payments@garigo.et',
        first_name: 'GariGo',
        last_name: 'Rider',
        callback_url: process.env.CHAPA_CALLBACK_URL,
        return_url: process.env.CHAPA_RETURN_URL,
        customization: {
          title: 'GariGo ride',
          description: `Trip ${reference}`,
        },
        meta: { card_token: providerToken, trip: reference },
      }),
    });
    const data = await res.json();
    if (!res.ok || data.status !== 'success') {
      throw new Error(data?.message || 'Chapa card charge init failed');
    }
    return {
      ok: true,
      providerTxnId: data.data?.tx_ref || txRef,
      status: 'pending',
      checkoutUrl: data.data?.checkout_url,
      stub: false,
      provider: 'chapa',
    };
  }

  if ((process.env.PAYMENTS_MODE || 'stub') === 'stub') {
    return {
      ok: true,
      providerTxnId: `vault_charge_${reference}`,
      status: 'paid',
      stub: true,
      provider: 'garigo_vault',
    };
  }

  throw new Error(
    'Card payments require STRIPE_SECRET_KEY or CHAPA_SECRET_KEY in live mode',
  );
}
