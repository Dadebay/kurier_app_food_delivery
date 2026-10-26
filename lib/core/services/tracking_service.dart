import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../constants/app_config.dart';
import '../models/pending_action.dart';
import '../network/api_client.dart';
import 'location_service.dart';
import 'offline_queue_service.dart';

/// Uploads fresh measurements every 15 seconds throughout the explicit shift,
/// including while stationary. Acquisition, queueing and stopping are guarded
/// by the same generation so delayed work cannot revive a finished shift.
class TrackingService extends ChangeNotifier {
  TrackingService({
    required LocationService location,
    required OfflineQueueService queue,
    required ApiClient api,
    Future<void> Function(bool keepAwake)? screenWake,
    this.interval = AppConfig.trackingInterval,
  }) : _location = location,
       _queue = queue,
       _api = api,
       _screenWake = screenWake ?? _holdScreen {
    _queue.addListener(_notify);
  }

  /// Held for exactly as long as the shift: a courier glancing at the next
  /// stop while driving should not have to wake the phone first. Android only
  /// honours it while the app is actually on screen, so this costs nothing
  /// once the courier pockets the phone — the foreground service, not this,
  /// is what keeps reporting alive then.
  static Future<void> _holdScreen(bool keepAwake) =>
      WakelockPlus.toggle(enable: keepAwake);

  final Duration interval;
  final Future<void> Function(bool keepAwake) _screenWake;
  final LocationService _location;
  final OfflineQueueService _queue;
  final ApiClient _api;
  Timer? _timer;
  String? _owner;
  int _generation = 0;
  bool _disposed = false;
  DateTime? _lastQueuedAt;
  Future<void>? _startInFlight;
  Future<void>? _sendInFlight;
  Future<void>? _stopInFlight;

  bool get running => _timer != null;

  /// Actual HTTP success, not the moment a fix entered the offline queue.
  DateTime? get lastSentAt => _queue.lastPingSentAt;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start(String courierId) {
    final owner = _api.accountId;
    if (_disposed || owner == null || !_api.authenticated) {
      return Future.value();
    }
    if (_owner == owner) return _startInFlight ?? Future.value();
    _owner = owner;
    final generation = ++_generation;
    final future = _start(owner, generation, _stopInFlight);
    _startInFlight = future;
    return future;
  }

  bool _valid(String owner, int generation) =>
      !_disposed &&
      _owner == owner &&
      _generation == generation &&
      _api.accountId == owner;

  Future<void> _start(
    String owner,
    int generation,
    Future<void>? stopping,
  ) async {
    await stopping;
    if (!_valid(owner, generation)) return;
    _location.setOwner(owner);
    _queue.beginTracking(owner);
    await _location.start();
    if (!_valid(owner, generation)) return;
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(_send()));
    unawaited(_send());
    unawaited(_setScreenWake(true));
    _notify();
  }

  /// Never fatal: a phone that refuses the wakelock still delivers orders.
  Future<void> _setScreenWake(bool keepAwake) async {
    try {
      await _screenWake(keepAwake);
    } catch (_) {
      // Platform without the API, or a plugin not registered under test.
    }
  }

  Future<void> _send() {
    if (_sendInFlight != null) return _sendInFlight!;
    final future = _sendFix();
    _sendInFlight = future;
    unawaited(
      future.then((_) {
        if (identical(_sendInFlight, future)) _sendInFlight = null;
      }),
    );
    return future;
  }

  Future<void> _sendFix() async {
    final owner = _owner;
    final generation = _generation;
    if (owner == null || !_valid(owner, generation)) return;
    try {
      final point = await _location.currentOrFix();
      if (!_valid(owner, generation) || point == null) return;
      final fix = _location.fix;
      if (fix == null || !fix.isFresh(DateTime.now())) return;
      if (_lastQueuedAt != null && !fix.recordedAt.isAfter(_lastQueuedAt!)) {
        return;
      }
      await _queue.enqueue(
        PendingAction(
          id: 'ping-${fix.recordedAt.microsecondsSinceEpoch}',
          ownerId: owner,
          kind: PendingActionKind.ping,
          path: ApiPaths.ping,
          method: 'PUT',
          body: fix.toJson(),
          createdAt: DateTime.now(),
        ),
      );
      if (_valid(owner, generation)) _lastQueuedAt = fix.recordedAt;
    } catch (_) {
      // A storage/platform error must not kill the periodic recovery loop.
    }
  }

  Future<void> stop() {
    if (_owner == null && _stopInFlight != null) return _stopInFlight!;
    final owner = _owner;
    _owner = null;
    _generation++;
    _timer?.cancel();
    _timer = null;
    _lastQueuedAt = null;
    unawaited(_setScreenWake(false));
    _queue.suspendTracking();
    final locationStopped = _location.stop();
    final sending = _sendInFlight;
    final future = _stop(owner, locationStopped, sending);
    _stopInFlight = future;
    _notify();
    return future;
  }

  Future<void> _stop(
    String? owner,
    Future<void> locationStopped,
    Future<void>? sending,
  ) async {
    await locationStopped;
    await sending;
    await _queue.discardTracking();
    if (owner == null || owner != _api.accountId) return;
    try {
      // All earlier PUTs finished and further retries are barred before DELETE.
      await _api.endTracking(owner);
    } catch (_) {
      // Offline: the server's existing marker expires by its normal TTL.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _queue.removeListener(_notify);
    unawaited(stop());
    super.dispose();
  }
}
