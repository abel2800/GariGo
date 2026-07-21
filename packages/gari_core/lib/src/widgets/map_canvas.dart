import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../models/models.dart';
import '../theme/colors.dart';

enum GariMapMode { day, night, heatmap }

/// Pin shown on [GariMapCanvas].
class GariMapPin {
  const GariMapPin({
    required this.point,
    this.color = GariColors.amber,
    this.icon = Icons.location_on,
    this.size = 36,
  });

  final LatLngPoint point;
  final Color color;
  final IconData icon;
  final double size;
}

/// Addis Ababa defaults.
class GariMapDefaults {
  static const addis = LatLngPoint(9.03, 38.75);
  static const boleMedhanialem = LatLngPoint(9.010, 38.780);
  static const megenagna = LatLngPoint(9.022, 38.802);
  static const ednaMall = LatLngPoint(8.998, 38.789);
  static const cmc = LatLngPoint(9.015, 38.830);
  static const ayat = LatLngPoint(9.040, 38.860);
  static const summit = LatLngPoint(9.020, 38.850);
  static const gerji = LatLngPoint(8.995, 38.810);

  /// Demo demand / driver density around Addis.
  static const heatPoints = <LatLngPoint>[
    LatLngPoint(9.015, 38.785),
    LatLngPoint(9.022, 38.802),
    LatLngPoint(9.000, 38.790),
    LatLngPoint(9.035, 38.820),
    LatLngPoint(9.010, 38.830),
    LatLngPoint(8.995, 38.810),
  ];

  static const demoDrivers = <LatLngPoint>[
    LatLngPoint(9.018, 38.788),
    LatLngPoint(9.025, 38.795),
    LatLngPoint(9.008, 38.775),
    LatLngPoint(9.030, 38.810),
    LatLngPoint(9.002, 38.800),
  ];
}

ll.LatLng _ll(LatLngPoint p) => ll.LatLng(p.lat, p.lng);

/// Real slippy map (Carto/OSM tiles). Works on web without Google/Mapbox keys.
class GariMapCanvas extends StatefulWidget {
  const GariMapCanvas({
    super.key,
    this.mode = GariMapMode.day,
    this.showRoute = false,
    this.showPulse = false,
    this.dimmed = false,
    this.interactive = true,
    this.center,
    this.zoom = 13,
    this.pickup,
    this.dropoff,
    this.pins = const [],
    this.child,
  });

  final GariMapMode mode;
  final bool showRoute;
  final bool showPulse;
  final bool dimmed;
  final bool interactive;
  final LatLngPoint? center;
  final double zoom;
  final LatLngPoint? pickup;
  final LatLngPoint? dropoff;
  final List<GariMapPin> pins;
  final Widget? child;

  @override
  State<GariMapCanvas> createState() => _GariMapCanvasState();
}

class _GariMapCanvasState extends State<GariMapCanvas> {
  late final MapController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MapController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LatLngPoint get _center {
    if (widget.center != null) return widget.center!;
    if (widget.pickup != null && widget.dropoff != null) {
      return LatLngPoint(
        (widget.pickup!.lat + widget.dropoff!.lat) / 2,
        (widget.pickup!.lng + widget.dropoff!.lng) / 2,
      );
    }
    return widget.pickup ??
        widget.dropoff ??
        GariMapDefaults.boleMedhanialem;
  }

  String get _tileUrl {
    // Proxied via GariGo API so Flutter web canvas gets CORS-friendly tiles
    final base = const String.fromEnvironment(
      'GARI_API_URL',
      defaultValue: 'http://localhost:4000',
    );
    final style = widget.mode == GariMapMode.night ? 'dark' : 'voyager';
    return '$base/tiles/$style/{z}/{x}/{y}.png';
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.pickup ??
        (widget.showRoute ? GariMapDefaults.boleMedhanialem : null);
    final dropoff = widget.dropoff ??
        (widget.showRoute ? GariMapDefaults.megenagna : null);

    final routePoints = <ll.LatLng>[];
    if (widget.showRoute && pickup != null && dropoff != null) {
      routePoints.addAll([_ll(pickup), _ll(dropoff)]);
    }

    final heat = widget.mode == GariMapMode.heatmap
        ? GariMapDefaults.heatPoints
        : const <LatLngPoint>[];

    final allPins = <GariMapPin>[
      ...widget.pins,
      if (pickup != null)
        GariMapPin(
          point: pickup,
          color: GariColors.emerald,
          icon: Icons.trip_origin,
          size: 28,
        ),
      if (dropoff != null)
        GariMapPin(
          point: dropoff,
          color: GariColors.crimson,
          icon: Icons.flag,
          size: 32,
        ),
      if (widget.showPulse && pickup == null && dropoff == null)
        GariMapPin(
          point: _center,
          color: GariColors.amber,
          icon: Icons.my_location,
          size: 40,
        ),
      if (widget.mode == GariMapMode.heatmap)
        ...GariMapDefaults.demoDrivers.map(
          (p) => GariMapPin(
            point: p,
            color: GariColors.emerald,
            icon: Icons.two_wheeler,
            size: 26,
          ),
        ),
    ];

    return Opacity(
      opacity: widget.dimmed ? 0.55 : 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _ll(_center),
              initialZoom: widget.zoom,
              minZoom: 10,
              maxZoom: 18,
              interactionOptions: InteractionOptions(
                flags: widget.interactive
                    ? InteractiveFlag.all & ~InteractiveFlag.rotate
                    : InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrl,
                userAgentPackageName: 'et.garigo.app',
              ),
              if (heat.isNotEmpty)
                CircleLayer(
                  circles: [
                    for (final p in heat)
                      CircleMarker(
                        point: _ll(p),
                        radius: 48,
                        useRadiusInMeter: false,
                        color: GariColors.amber.withValues(alpha: 0.22),
                        borderColor: GariColors.amber.withValues(alpha: 0.35),
                        borderStrokeWidth: 1,
                      ),
                  ],
                ),
              if (routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 4.5,
                      color: GariColors.emerald,
                      borderStrokeWidth: 2,
                      borderColor: Colors.white.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              if (widget.showPulse)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _ll(_center),
                      radius: 28,
                      useRadiusInMeter: false,
                      color: GariColors.amber.withValues(alpha: 0.2),
                      borderColor: GariColors.amber,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (final pin in allPins)
                    Marker(
                      point: _ll(pin.point),
                      width: pin.size + 8,
                      height: pin.size + 8,
                      alignment: Alignment.center,
                      child: Icon(
                        pin.icon,
                        color: pin.color,
                        size: pin.size,
                        shadows: const [
                          Shadow(blurRadius: 6, color: Colors.black38),
                        ],
                      ),
                    ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap',
                    onTap: () {},
                  ),
                  const TextSourceAttribution('CARTO'),
                ],
              ),
            ],
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}
