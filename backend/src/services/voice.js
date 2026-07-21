/**
 * Masked calling — stub. Production: Twilio Proxy / similar.
 */
export async function createMaskedSession({ riderPhone, driverPhone, tripId }) {
  if (process.env.VOICE_PROXY_MODE === 'stub' || !process.env.TWILIO_PROXY_SERVICE_SID) {
    return {
      ok: true,
      stub: true,
      proxyNumber: '+251911000000',
      sessionId: `stub_call_${tripId}`,
      note: 'Configure Twilio Proxy for real masked calling',
    };
  }
  throw new Error('Twilio Proxy adapter not wired yet');
}
