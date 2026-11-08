import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_config.dart';
import '../models/pending_action.dart';
import '../network/api_client.dart';
import 'location_service.dart';
import 'offline_queue_service.dart';

/// Reports the courier's position to the server every few minutes.
///
/// This is the feature the customer and the operator actually see: slide 8 —
/// "курьер отображается на карте значком машины, обновляется каждые 3–5 минут".
///
/// The ping goes through the offline queue rather than straight to Dio, so a
/// position captured in a basement is still delivered once the courier is back
/// on the street.
class TrackingService extends ChangeNotifier {
  TrackingService({
    required LocationService location,
    required OfflineQueueService queue,
    required ApiClient api,
  }) : _location = location,
       _queue = queue,
       _api = api;

  final LocationService _location;
  final OfflineQueueService _queue;
  final ApiClient _api;

  Timer? _timer;
  LatLng? _lastSent;
  DateTime? _lastSentAt;
  String? _courierId;

  bool get running => _timer != null;
  DateTime? get lastSentAt => _lastSentAt;

  /// Starts reporting. Called when the courier goes on shift.
  Future<void> start(String courierId) async {
    _courierId = courierId;
    if (_timer != null) return;

    await _location.start();
    // Send one immediately so the operator sees the courier the moment the
    // shift starts, then settle into the interval.
    await _send();
    _timer = Timer.periodic(AppConfig.trackingInterval, (_) => _send());
    notifyListeners();
  }

  /// Stops reporting — courier went off shift or signed out. Also tells the
  /// server to drop the last known position, so the operator/customer stop
  /// seeing a marker for a courier who is no longer actually tracking.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _lastSent = null;
    notifyListeners();

    if (_courierId == null) return;
    _courierId = null;
    try {
      await _api.delete(ApiPaths.ping);
    } catch (_) {
      // Best-effort cleanup — the position simply goes stale server-side if
      // this doesn't land, nothing to retry once tracking has stopped.
    }
  }

  Future<void> _send() async {
    final courierId = _courierId;
    if (courierId == null) return;

    final point = await _location.currentOrFix();
    if (point == null) return;

    // The reading may be a remembered one — the courier is inside a building
    // and the receiver has nothing new. Send it anyway, but with the time it
    // was actually taken, so the operator sees a position with an honest age
    // instead of an old point pretending to be live. Past the server's
    // ten-minute window it would only be rejected, so it is dropped here.
    final recordedAt = _location.currentAt ?? DateTime.now();
    final age = DateTime.now().difference(recordedAt);
    if (age > const Duration(minutes: 9)) return;

    // Skip the upload when the courier is parked — nothing on the operator's
    // screen would change, and it saves the data plan.
    final previous = _lastSent;
    if (previous != null &&
        LocationService.metersBetween(previous, point) <
            AppConfig.minTrackingDistanceMeters) {
      return;
    }

    await _queue.enqueue(
      PendingAction(
        id: 'ping-${DateTime.now().microsecondsSinceEpoch}',
        kind: PendingActionKind.ping,
        path: ApiPaths.ping,
        method: 'PUT',
        body: {
          'latitude': point.latitude,
          'longitude': point.longitude,
          'heading': _location.heading,
          if (_location.accuracy != null) 'accuracy': _location.accuracy,
          if (_location.speed != null) 'speed': _location.speed,
          'recordedAt': recordedAt.toUtc().toIso8601String(),
        },
        createdAt: DateTime.now(),
      ),
    );

    _lastSent = point;
    _lastSentAt = DateTime.now();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
