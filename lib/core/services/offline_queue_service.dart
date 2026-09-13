import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_config.dart';
import '../models/pending_action.dart';
import '../network/api_client.dart';
import 'connectivity_service.dart';

/// Durable outbox for everything the courier does.
///
/// The rule is simple and has no "online" special case: a status tap is written
/// to the Hive box first, and only then does the flusher try to send it. If the
/// app is killed in a lift with no signal, the tap is still on disk and goes out
/// on the next launch.
///
/// Positions captured with no signal are kept, not collapsed: the courier's
/// whole offline stretch goes out oldest-first once the connection is back.
class OfflineQueueService extends ChangeNotifier {
  OfflineQueueService({required ApiClient api, required ConnectivityService connectivity})
    : _api = api,
      _connectivity = connectivity {
    _connectivity.addListener(_onConnectivityChanged);
  }

  static const String boxName = 'pending_actions';

  final ApiClient _api;
  final ConnectivityService _connectivity;

  late final Box<String> _box;
  Timer? _timer;
  bool _flushing = false;
  bool _ready = false;

  /// How many writes are still waiting — drives the "2 статуса в очереди"
  /// line on the route screen.
  int get pendingCount => _ready ? _box.length : 0;

  bool get hasPending => pendingCount > 0;

  /// Positions still on the phone, waiting for a connection.
  int get pendingPingCount => _ready ? _countPings() : 0;

  int _syncedPingCount = 0;

  /// Positions this session has successfully handed to the server — the
  /// courier's proof that the offline stretch actually went out.
  int get syncedPingCount => _syncedPingCount;

  int _countPings() {
    var count = 0;
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw == null) continue;
      if (PendingAction.decode(raw).kind == PendingActionKind.ping) count++;
    }
    return count;
  }

  /// Fires whenever a queued write is rejected outright (409/403) rather than
  /// just failing to reach the server — the caller's local state is now
  /// provably stale and needs a fresh read, not a retry of the same write.
  final _conflicts = StreamController<void>.broadcast();
  Stream<void> get conflicts => _conflicts.stream;

  Future<void> init() async {
    _box = await Hive.openBox<String>(boxName);
    _ready = true;
    _timer = Timer.periodic(AppConfig.queueFlushInterval, (_) => flush());
    unawaited(flush());
    notifyListeners();
  }

  /// Records an action and immediately tries to send it.
  ///
  /// Queued positions used to be collapsed to the newest one, which threw away
  /// every point captured in a dead zone. They are kept now so the driven line
  /// survives the outage; only the buffer's own ceiling drops anything, and it
  /// drops the oldest.
  Future<void> enqueue(PendingAction action) async {
    if (!_ready) return;

    await _box.put(action.id, action.encode());
    if (action.kind == PendingActionKind.ping) await _trimPingBuffer();
    notifyListeners();
    unawaited(flush());
  }

  /// Keeps the newest [AppConfig.maxBufferedPings] positions. A phone that
  /// never regains signal would otherwise fill its storage with a track
  /// nobody can use any more.
  Future<void> _trimPingBuffer() async {
    final pings = <String, DateTime>{};
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw == null) continue;
      final action = PendingAction.decode(raw);
      if (action.kind == PendingActionKind.ping) {
        pings[key.toString()] = action.createdAt;
      }
    }
    if (pings.length <= AppConfig.maxBufferedPings) return;

    final oldestFirst = pings.keys.toList()
      ..sort((a, b) => pings[a]!.compareTo(pings[b]!));
    await _box.deleteAll(
      oldestFirst.take(pings.length - AppConfig.maxBufferedPings),
    );
  }

  /// Sends everything in the box, oldest first, stopping at the first failure
  /// so ordering is preserved (a "delivered" never overtakes a "picked up").
  Future<void> flush() async {
    if (!_ready || _flushing || _box.isEmpty) return;
    if (_connectivity.offline) return;
    if (AppConfig.useMockData) {
      // Demo mode: nothing to talk to, so drain the box to keep the UI honest.
      await _box.clear();
      notifyListeners();
      return;
    }

    _flushing = true;
    try {
      final keys = _box.keys.toList()
        ..sort((a, b) {
          final left = PendingAction.decode(_box.get(a)!).createdAt;
          final right = PendingAction.decode(_box.get(b)!).createdAt;
          return left.compareTo(right);
        });

      for (final key in keys) {
        final raw = _box.get(key);
        if (raw == null) continue;
        final action = PendingAction.decode(raw);

        try {
          final response = switch (action.method) {
            'PATCH' => await _api.patch(action.path, data: action.body),
            'PUT' => await _api.put(action.path, data: action.body),
            _ => await _api.post(action.path, data: action.body),
          };
          final code = response.statusCode ?? 0;

          if (code >= 200 && code < 300) {
            await _box.delete(key);
            if (action.kind == PendingActionKind.ping) _syncedPingCount++;
            continue;
          }

          // 4xx means the server rejected this action outright — replaying it
          // forever would wedge the queue, so drop it and move on.
          if (code >= 400 && code < 500) {
            dev.log('dropping ${action.kind.name} ${action.id}: HTTP $code', name: 'OfflineQueue');
            await _box.delete(key);
            // A status write specifically rejected as a conflict (stale
            // version) or forbidden (wrong courier / illegal transition)
            // means the local order is no longer trustworthy — the screen
            // must re-fetch it rather than keep showing the optimistic state.
            if (action.kind == PendingActionKind.status &&
                (code == 409 || code == 403)) {
              _conflicts.add(null);
            }
            continue;
          }

          // 5xx / unknown: keep it and retry on the next tick.
          action.attempts++;
          await _box.put(key, action.encode());
          break;
        } catch (error) {
          // Network died mid-flush. Stop here; ordering stays intact.
          action.attempts++;
          await _box.put(key, action.encode());
          dev.log('flush stopped: $error', name: 'OfflineQueue');
          break;
        }
      }
    } finally {
      _flushing = false;
      notifyListeners();
    }
  }

  void _onConnectivityChanged() {
    if (_connectivity.online) unawaited(flush());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectivity.removeListener(_onConnectivityChanged);
    unawaited(_conflicts.close());
    super.dispose();
  }
}
