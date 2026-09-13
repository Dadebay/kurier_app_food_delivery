import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_config.dart';
import '../services/location_service.dart';
import '../services/tile_cache_service.dart';
import '../theme/app_colors.dart';
import 'car_marker.dart';

/// The map, drawn on our own tile server and cached to disk.
///
/// Deliberately dumb: it takes points and draws them. All routing and status
/// logic lives in the screen above it, so the same widget serves the route
/// screen, the order detail preview and anything added later.
class CourierMap extends StatefulWidget {
  const CourierMap({
    super.key,
    this.courierPoint,
    this.courierHeading = 0,
    this.branchPoint,
    this.stops = const [],
    this.activeStopIndex,
    this.routePoints = const [],
    this.initialCenter,
    this.initialZoom,
    this.follow = true,
    this.interactive = true,
    this.onStopTap,
    this.onMapTap,
    this.padding = EdgeInsets.zero,
  });

  final LatLng? courierPoint;
  final double courierHeading;
  final LatLng? branchPoint;

  /// Delivery points in visiting order — numbered 1..n on the map.
  final List<LatLng> stops;

  /// Which stop is being driven to right now; it gets the orange pin.
  final int? activeStopIndex;

  final List<LatLng> routePoints;
  final LatLng? initialCenter;
  final double? initialZoom;

  /// Keep the camera on the courier as they drive. Any manual pan switches
  /// this off until the "recentre" button is pressed.
  final bool follow;

  final bool interactive;
  final void Function(int index)? onStopTap;
  final VoidCallback? onMapTap;

  /// Keeps the route clear of the header card and the bottom sheet when the
  /// camera fits the whole trip.
  final EdgeInsets padding;

  @override
  State<CourierMap> createState() => CourierMapState();
}

class CourierMapState extends State<CourierMap> {
  final MapController _controller = MapController();
  bool _userMoved = false;
  bool _firstFixApplied = false;

  /// Opening the map with a position already in hand — a live fix or the one
  /// remembered from the last shift — should show the courier straight away,
  /// not the city centre. [didUpdateWidget] only fires on later changes, so
  /// the very first frame has to be handled here.
  @override
  void initState() {
    super.initState();
    final point = widget.courierPoint;
    if (point != null) {
      _firstFixApplied = true;
      _move(point, AppConfig.followZoom);
    }
  }

  /// Whether the crosshair button has anything to centre on.
  bool get canRecenter => widget.courierPoint != null;

  @override
  void didUpdateWidget(covariant CourierMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    final point = widget.courierPoint;
    if (point == null) return;

    // Snap to the courier the first time GPS answers, wherever the camera was.
    if (!_firstFixApplied) {
      _firstFixApplied = true;
      _move(point, AppConfig.followZoom);
      return;
    }

    if (widget.follow && !_userMoved && point != oldWidget.courierPoint) {
      _move(point, _controller.camera.zoom);
    }
  }

  void _move(LatLng center, double zoom) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.move(center, zoom);
    });
  }

  /// Re-centres on the courier — bound to the crosshair button.
  void recenter() {
    final point = widget.courierPoint;
    if (point == null) return;
    setState(() => _userMoved = false);
    _controller.move(point, AppConfig.followZoom);
  }

  /// Fits the whole route on screen.
  void fitRoute() {
    final points = [
      ...widget.routePoints,
      ...widget.stops,
      if (widget.courierPoint != null) widget.courierPoint!,
      if (widget.branchPoint != null) widget.branchPoint!,
    ];
    if (points.length < 2) return;

    setState(() => _userMoved = true);
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: widget.padding + const EdgeInsets.all(48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter:
            widget.initialCenter ??
            widget.courierPoint ??
            LocationService.fallbackCenter,
        initialZoom: widget.initialZoom ?? AppConfig.defaultZoom,
        minZoom: AppConfig.minZoom,
        maxZoom: AppConfig.maxZoom,
        backgroundColor: AppColors.cream,
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              // Rotation off: a courier glancing at the phone needs north up.
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
        onPositionChanged: (position, hasGesture) {
          if (hasGesture && !_userMoved) setState(() => _userMoved = true);
        },
        onTap: (_, _) => widget.onMapTap?.call(),
      ),
      children: [
        TileLayer(
          urlTemplate: AppConfig.mapTileUrl,
          userAgentPackageName: AppConfig.mapUserAgent,
          tileProvider: TileCacheService.tileProvider,
          // Three tiles of slack outside the viewport — far fewer grey gaps
          // while panning on a slow connection.
          keepBuffer: 3,
        ),
        if (widget.routePoints.length > 1)
          PolylineLayer(
            polylines: [
              // Casing first, so the orange line stays readable over dark
              // map features.
              Polyline(
                points: widget.routePoints,
                strokeWidth: 9,
                color: AppColors.white.withValues(alpha: 0.9),
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
              Polyline(
                points: widget.routePoints,
                strokeWidth: 5.5,
                color: AppColors.orange,
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (widget.branchPoint != null)
              Marker(
                point: widget.branchPoint!,
                width: 26,
                height: 26,
                child: const BranchMarker(),
              ),
            for (var i = 0; i < widget.stops.length; i++)
              Marker(
                point: widget.stops[i],
                width: 38,
                height: 38,
                child: GestureDetector(
                  onTap: () => widget.onStopTap?.call(i),
                  child: ClientMarker(
                    index: i + 1,
                    active: widget.activeStopIndex == i,
                  ),
                ),
              ),
            if (widget.courierPoint != null)
              Marker(
                point: widget.courierPoint!,
                width: 54,
                height: 54,
                child: CarMarker(heading: widget.courierHeading),
              ),
          ],
        ),
      ],
    );
  }
}
