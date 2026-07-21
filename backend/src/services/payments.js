/**
 * Payment rails abstraction.
 * PAYMENTS_MODE=stub | live
 *
 * Card charges use the card vault (Stripe / Chapa / vault stub).
 */
import { chargeSavedCard } from './cardVault.js';

export async function chargePayment({
  method,
  amount,
  phone,
  reference,
  cardToken,
}) {
  const mode = process.env.PAYMENTS_MODE || 'stub';

  if (method === 'card') {
    return chargeSavedCard({
      providerToken: cardToken || `vault_orphan_${reference}`,
      amount,
      reference,
    });
  }

  if (mode === 'stub' || method === 'cash' || method === 'wallet') {
    return {
      ok: true,
      providerTxnId: `stub_${method}_${Date.now()}`,
      status: method === 'cash' ? 'cash_owed' : 'paid',
      stub: true,
    };
  }

  switch (method) {
    case 'telebirr':
      return telebirrCharge({ amount, phone, reference });
    case 'cbe_birr':
      return cbeCharge({ amount, phone, reference });
    case 'hellocash':
      return helloCashCharge({ amount, phone, reference });
    default:
      throw new Error(`Unsupported payment method: ${method}`);
  }
}

async function telebirrCharge({ amount, phone, reference }) {
  if (!process.env.TELEBIRR_APP_ID) {
    return {
      ok: true,
      providerTxnId: `telebirr_stub_${reference}`,
      status: 'paid',
      stub: true,
    };
  }
  throw new Error('Telebirr live adapter not configured — add API client here');
}

async function cbeCharge({ amount, phone, reference }) {
  if (!process.env.CBE_BIRR_API_KEY) {
    return {
      ok: true,
      providerTxnId: `cbe_stub_${reference}`,
      status: 'paid',
      stub: true,
    };
  }
  throw new Error('CBE Birr live adapter not configured');
}

async function helloCashCharge({ amount, phone, reference }) {
  if (!process.env.HELLOCASH_API_KEY) {
    return {
      ok: true,
      providerTxnId: `hc_stub_${reference}`,
      status: 'paid',
      stub: true,
    };
  }
  throw new Error('HelloCash live adapter not configured');
}

export async function payoutDriver({ method, amount, destination, reference }) {
  const mode = process.env.PAYMENTS_MODE || 'stub';
  if (mode === 'stub') {
    return {
      ok: true,
      providerTxnId: `payout_stub_${method}_${Date.now()}`,
      fee: Math.max(5, Math.round(amount * 0.02)),
      stub: true,
    };
  }
  return {
    ok: true,
    providerTxnId: `payout_${method}_${reference}`,
    fee: Math.max(5, Math.round(amount * 0.02)),
  };
}
