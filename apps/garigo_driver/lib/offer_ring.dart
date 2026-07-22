import 'offer_ring_stub.dart'
    if (dart.library.html) 'offer_ring_web.dart' as impl;

/// Rings / beeps while a ride offer is on screen.
class OfferRing {
  static void start() => impl.startOfferRing();
  static void stop() => impl.stopOfferRing();
}
