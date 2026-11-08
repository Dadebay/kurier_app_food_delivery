import 'dart:developer' as dev;

import 'package:latlong2/latlong.dart';

import '../network/api_client.dart';

/// What the server actually knows about the road route right now — distinct
/// from "no line to draw", which can mean several different things to the
/// courier (still calculating, genuinely no path, or simply no stops).
enum RoutingStatus { ready, unavailable, noStops }

/// A driving route: the line to draw plus the numbers for the header card.
class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.courierPoint,
    this.status = RoutingStatus.ready,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final LatLng? courierPoint;
  final RoutingStatus status;

  double get distanceKm => distanceMeters / 1000;
  int get durationMinutes => (durationSeconds / 60).round();

  static const empty = RouteResult(
    points: [],
    distanceMeters: 0,
    durationSeconds: 0,
    status: RoutingStatus.unavailable,
  );

  static const noStops = RouteResult(
    points: [],
    distanceMeters: 0,
    durationSeconds: 0,
    status: RoutingStatus.noStops,
  );

  bool get isEmpty => points.isEmpty;
}

/// Turns a list of stops into a drivable line.
///
/// The backend is the sole source of truth for the courier route: it combines
/// the authenticated courier's latest GPS point, pickup branch and assigned
/// stops. This never falls back to a straight line or any other client-side
/// guess — a route the server hasn't actually driven and confirmed is worse
/// than no line at all, since the markers (stops, branch, courier) are drawn
/// independently of this and stay visible either way.
class RoutingService {
  RoutingService(this._api);

  final ApiClient _api;

  /// Route through [stops] in the given order. The first entry is the courier's
  /// current position, the rest are delivery points.
  Future<RouteResult> route(List<LatLng> stops) async {
    if (stops.length < 2) {
      dev.log(
        'no line: ${stops.length} stop(s) — need the courier plus at least '
        'one delivery point',
        name: 'RoutingService',
      );
      return RouteResult.noStops;
    }

    return _request();
  }

  /// Route from the authenticated courier's latest GPS point back to the
  /// branch snapshotted on an order they delivered.
  Future<RouteResult> returnToBranch(String orderId) =>
      _request(query: {'returnOrderId': orderId});

  Future<RouteResult> _request({Map<String, dynamic>? query}) async {
    try {
      final response = await _api.get(ApiPaths.courierRoute, query: query);
      if (response.statusCode != 200 ||
          response.data is! Map<String, dynamic>) {
        return _empty('HTTP ${response.statusCode} — server gave no route');
      }
      final body = response.data as Map<String, dynamic>;

      final status = body['routingStatus'] as String?;
      switch (status) {
        case 'NO_STOPS':
          dev.log('no line: server reports no stops', name: 'RoutingService');
          return RouteResult.noStops;
        case 'READY':
          break;
        default:
          // UNAVAILABLE, or a status we don't recognise yet — keep the
          // markers, draw no line. UNAVAILABLE almost always means the server
          // has no recent GPS point for this courier to start the route from,
          // which is why the line comes and goes rather than never appearing.
          return _empty('routingStatus=$status');
      }

      final route = body['route'];
      if (route is! Map<String, dynamic>) {
        return _empty('status READY but no route object in the body');
      }
      final geometry = route['geometry'];
      if (geometry is! Map<String, dynamic> ||
          geometry['coordinates'] is! List<dynamic>) {
        return _empty('route has no usable geometry');
      }
      final coords = geometry['coordinates'] as List<dynamic>;
      if (coords.length < 2) {
        return _empty('geometry has ${coords.length} point(s), need 2+');
      }

      LatLng? courierPoint;
      final waypoints = route['waypoints'];
      if (waypoints is List<dynamic>) {
        for (final value in waypoints.whereType<Map<String, dynamic>>()) {
          if (value['kind'] != 'COURIER') continue;
          final latitude = value['latitude'];
          final longitude = value['longitude'];
          if (latitude is num && longitude is num) {
            courierPoint = LatLng(latitude.toDouble(), longitude.toDouble());
          }
          break;
        }
      }
      dev.log(
        courierPoint == null
            ? '\x1B[33m⚠️ route courier waypoint=null\x1B[0m'
            : '\x1B[32m✅ route courier waypoint present\x1B[0m',
        name: 'RoutingService',
      );

      return RouteResult(
        // GeoJSON is [lng, lat]; LatLng is the other way round.
        points: coords
            .whereType<List<dynamic>>()
            .map(
              (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
            )
            .toList(),
        distanceMeters: (route['distanceMeters'] as num).toDouble(),
        durationSeconds: (route['durationSeconds'] as num).toDouble(),
        courierPoint: courierPoint,
      );
    } catch (error) {
      dev.log(
        'route request failed: ${error.runtimeType}',
        name: 'RoutingService',
      );
      return RouteResult.empty;
    }
  }

  /// Every path that ends in "no line on the map" goes through here, so the
  /// map going blank always leaves a reason behind. Without this the six
  /// early returns above were indistinguishable from each other — and from
  /// the route simply not having been requested.
  static RouteResult _empty(String reason) {
    dev.log('\x1B[33m⚠️ no line: $reason\x1B[0m', name: 'RoutingService');
    return RouteResult.empty;
  }
}
