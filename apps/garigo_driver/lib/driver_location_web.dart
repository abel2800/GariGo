import 'driver_location.dart';

/// On web we default matching location in setOnline (Bole hub).
/// Browser geolocation can be added later with a stable package API.
Future<GeoPoint?> currentDriverLocation() async => null;
