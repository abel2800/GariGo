import 'driver_location_stub.dart'
    if (dart.library.html) 'driver_location_web.dart' as impl;

class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// Browser geolocation when available; otherwise null.
Future<GeoPoint?> currentDriverLocation() => impl.currentDriverLocation();
