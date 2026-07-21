/**
 * FCM push — stub until Firebase service account is configured.
 */
export async function sendPush(fcmToken, { title, body, data = {} }) {
  if (!fcmToken) return { ok: false, reason: 'no_token' };

  if (!process.env.FIREBASE_PROJECT_ID) {
    console.log(`[FCM:stub] → ${fcmToken.slice(0, 12)}… ${title}: ${body}`);
    return { ok: true, stub: true };
  }

  // Production: use firebase-admin with service account
  console.log('[FCM] Configure firebase-admin to send live pushes');
  return { ok: false, reason: 'firebase_not_wired' };
}
