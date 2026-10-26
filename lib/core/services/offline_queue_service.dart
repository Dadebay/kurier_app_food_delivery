import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_config.dart';
import '../models/location_fix.dart';
import '../models/pending_action.dart';
import '../network/api_client.dart';
import 'connectivity_service.dart';

/// Durable ordered status writes; only the newest location is useful to the
/// backend's latest-position endpoint. Every new action is scoped to its owner.
class OfflineQueueService extends ChangeNotifier {
  OfflineQueueService({
    required ApiClient api,
    required ConnectivityService connectivity,
  }) : _api = api,
       _connectivity = connectivity {
    _connectivity.addListener(_onConnectivityChanged);
  }

  static const String boxName = 'pending_actions';
  final ApiClient _api;
  final ConnectivityService _connectivity;
  late final Box<String> _box;
  Timer? _timer;
  Future<void>? _flushInFlight;
  bool _flushAgain = false;
  Future<void>? _pingInFlight;
  String? _trackingOwner;
  int _trackingGeneration = 0;
  bool _ready = false;
  bool _disposed = false;
  DateTime? _retryAfter;
  DateTime? _lastPingSentAt;
  int _syncedPingCount = 0;
  final _conflicts = StreamController<void>.broadcast();

  Stream<void> get conflicts => _conflicts.stream;
  int get pendingCount => _ready ? _box.length : 0;
  bool get hasPending => pendingCount > 0;
  int get pendingPingCount => _ready
      ? _box.values
            .where(
              (raw) => PendingAction.decode(raw).kind == PendingActionKind.ping,
            )
            .length
      : 0;
  int get syncedPingCount => _syncedPingCount;
  DateTime? get lastPingSentAt => _lastPingSentAt;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> init() async {
    _box = await Hive.openBox<String>(boxName);
    _ready = true;
    // No running shift has been restored yet. Never replay the previous
    // process's pings before the user/session and location service are ready.
    await _deletePings();
    _timer = Timer.periodic(
      AppConfig.queueFlushInterval,
      (_) => unawaited(flush()),
    );
    unawaited(flush());
    _notify();
  }

  void beginTracking(String owner) {
    _trackingOwner = owner;
    _trackingGeneration++;
    _lastPingSentAt = null;
    _syncedPingCount = 0;
  }

  /// Synchronous barrier: no queued request or 401 retry may start after this.
  void suspendTracking() {
    _trackingOwner = null;
    _trackingGeneration++;
  }

  Future<void> discardTracking() async {
    await _pingInFlight;
    if (_ready) await _deletePings();
    _notify();
  }

  Future<void> _deletePings() => _box.deleteAll(
    _box.keys.where((key) {
      final raw = _box.get(key);
      return raw != null &&
          PendingAction.decode(raw).kind == PendingActionKind.ping;
    }).toList(),
  );

  Future<void> enqueue(PendingAction action) async {
    if (!_ready) throw StateError('Offline queue has not been initialized');
    final owner = action.ownerId ?? _api.accountId;
    if (owner == null || owner != _api.accountId) return;
    if (action.kind == PendingActionKind.ping && _trackingOwner != owner) {
      return;
    }
    final owned = PendingAction.fromJson({
      ...action.toJson(),
      'owner_id': owner,
    });
    // A stable slot coalesces offline fixes. The raw-value comparison in flush
    // protects a newer fix from completion/failure of an older HTTP request.
    final key = action.kind == PendingActionKind.ping
        ? 'ping:$owner'
        : action.id;
    await _box.put(key, owned.encode());
    _notify();
    unawaited(flush());
  }

  Future<void> flush() {
    if (_flushInFlight != null) {
      _flushAgain = true;
      return _flushInFlight!;
    }
    final future = _drain();
    _flushInFlight = future;
    unawaited(
      future.then((_) {
        if (identical(_flushInFlight, future)) _flushInFlight = null;
      }),
    );
    return future;
  }

  Future<void> _drain() async {
    do {
      _flushAgain = false;
      await _flush();
    } while (_flushAgain && !_disposed);
  }

  Future<void> _flush() async {
    if (!_ready ||
        _disposed ||
        _box.isEmpty ||
        _connectivity.offline ||
        !_api.authenticated) {
      return;
    }
    if (_retryAfter != null && DateTime.now().isBefore(_retryAfter!)) return;
    final owner = _api.accountId;
    final session = _api.sessionGeneration;
    try {
      final keys = _box.keys.toList()
        ..sort(
          (a, b) => PendingAction.decode(
            _box.get(a)!,
          ).createdAt.compareTo(PendingAction.decode(_box.get(b)!).createdAt),
        );
      for (final key in keys) {
        if (_disposed ||
            owner != _api.accountId ||
            session != _api.sessionGeneration) {
          break;
        }
        final raw = _box.get(key);
        if (raw == null) continue;
        final action = PendingAction.decode(raw);
        // Legacy actions with unknown owners stay on disk for reconciliation;
        // never silently assign another courier's offline action at login.
        if (action.ownerId != owner) continue;
        final ping = action.kind == PendingActionKind.ping;
        final generation = _trackingGeneration;
        bool allowed() =>
            !ping ||
            (_trackingOwner == owner && generation == _trackingGeneration);
        if (ping) {
          final at = DateTime.tryParse(
            action.body['recordedAt'] as String? ?? '',
          );
          final age = at == null ? null : DateTime.now().difference(at);
          if (!allowed() ||
              age == null ||
              age.isNegative ||
              age > LocationFix.freshness) {
            if (_box.get(key) == raw) await _box.delete(key);
            continue;
          }
        }
        final done = Completer<void>();
        if (ping) _pingInFlight = done.future;
        try {
          final response = AppConfig.useMockData
              ? null
              : await _api.sendQueued(action, stillAllowed: allowed);
          final code =
              response?.statusCode ?? (AppConfig.useMockData ? 200 : 0);
          if (code >= 200 && code < 300) {
            if (_box.get(key) == raw) await _box.delete(key);
            if (ping && allowed()) {
              _syncedPingCount++;
              _lastPingSentAt = DateTime.now();
            }
            continue;
          }
          // Authentication/network/rate-limit failures are retryable writes.
          if (code == 401 ||
              code == 408 ||
              code == 429 ||
              code >= 500 ||
              code == 0) {
            final retrySeconds = int.tryParse(
              response?.headers.value('retry-after') ?? '',
            );
            _retryAfter = DateTime.now().add(
              retrySeconds != null &&
                      retrySeconds > AppConfig.queueFlushInterval.inSeconds
                  ? Duration(seconds: retrySeconds)
                  : AppConfig.queueFlushInterval,
            );
            break;
          }
          if (code >= 400 && code < 500) {
            if (_box.get(key) == raw) await _box.delete(key);
            if (action.kind == PendingActionKind.status &&
                (code == 403 || code == 409)) {
              _conflicts.add(null);
            }
            continue;
          }
          break;
        } catch (_) {
          if (_box.get(key) == raw && allowed()) {
            action.attempts++;
            await _box.put(key, action.encode());
          }
          break;
        } finally {
          done.complete();
          if (ping && identical(_pingInFlight, done.future)) {
            _pingInFlight = null;
          }
        }
      }
    } finally {
      _notify();
    }
  }

  void _onConnectivityChanged() {
    if (_connectivity.online) unawaited(flush());
  }

  @override
  void dispose() {
    _disposed = true;
    suspendTracking();
    _timer?.cancel();
    _connectivity.removeListener(_onConnectivityChanged);
    unawaited(_conflicts.close());
    super.dispose();
  }
}
