import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive_ce/hive.dart' as cache;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kurier_app/core/data/auth_repository.dart';
import 'package:kurier_app/core/data/courier_repository.dart';
import 'package:kurier_app/core/models/pending_action.dart';
import 'package:kurier_app/core/network/api_client.dart';
import 'package:kurier_app/core/services/connectivity_service.dart';
import 'package:kurier_app/core/services/offline_queue_service.dart';

class TestConnectivity extends ChangeNotifier implements ConnectivityService {
  bool connected = true;
  @override
  bool get online => connected;
  @override
  bool get offline => !connected;
}

class Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  int status = 200;
  Completer<void>? hold;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    await hold?.future;
    return ResponseBody.fromString(
      '{}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

PendingAction ping(String id, DateTime at, {String? owner = 'a'}) =>
    PendingAction(
      id: id,
      ownerId: owner,
      kind: PendingActionKind.ping,
      method: 'PUT',
      path: ApiPaths.ping,
      body: {
        'latitude': 37.0,
        'longitude': 58.0,
        'recordedAt': at.toUtc().toIso8601String(),
      },
      createdAt: at,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ApiClient api;
  late Adapter adapter;
  late OfflineQueueService queue;
  late TestConnectivity connectivity;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('courier-queue-test');
    Hive.init(directory.path);
    cache.Hive.init('${directory.path}/cache');
    api = ApiClient()
      ..accountId = 'a'
      ..token = 'test-token';
    adapter = Adapter();
    api.raw.httpClientAdapter = adapter;
    connectivity = TestConnectivity();
    queue = OfflineQueueService(api: api, connectivity: connectivity);
    await queue.init();
    await queue.flush();
  });
  tearDown(() async {
    await queue.flush();
    queue.dispose();
    connectivity.dispose();
    api.raw.close(force: true);
    await Hive.close();
    await cache.Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'offline positions coalesce; stale positions and previous-process pings are discarded',
    () async {
      connectivity.connected = false;
      queue.beginTracking('a');
      final now = DateTime.now();
      await queue.enqueue(
        ping('old', now.subtract(const Duration(seconds: 15))),
      );
      await queue.enqueue(ping('new', now));
      expect(queue.pendingPingCount, 1);
      connectivity.connected = true;
      await queue.flush();
      expect(adapter.calls.length, 1);
      expect(
        adapter.calls.single.data['recordedAt'],
        now.toUtc().toIso8601String(),
      );
      expect(queue.syncedPingCount, 1);
      expect(queue.lastPingSentAt, isNotNull);
      connectivity.connected = false;
      await queue.enqueue(
        ping('stale', now.subtract(const Duration(minutes: 2))),
      );
      connectivity.connected = true;
      await queue.flush();
      expect(adapter.calls.length, 1);
      expect(queue.pendingPingCount, 0);
      connectivity.connected = false;
      await queue.enqueue(ping('previous-process', now));
      await queue.flush();
      queue.dispose();
      queue = OfflineQueueService(api: api, connectivity: connectivity);
      await queue.init();
      expect(queue.pendingPingCount, 0);
    },
  );

  test('a completed old PUT cannot delete the newer coalesced fix', () async {
    queue.beginTracking('a');
    adapter.hold = Completer<void>();
    final now = DateTime.now();
    await queue.enqueue(
      ping('first', now.subtract(const Duration(seconds: 1))),
    );
    // Allow Dio's interceptor/adapter to receive the first request.
    for (var i = 0; i < 20 && adapter.calls.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(adapter.calls.length, 1);
    await queue.enqueue(ping('second', now));
    adapter.hold!.complete();
    await queue.flush();
    await queue.flush();
    expect(adapter.calls.length, 2);
    expect(queue.pendingPingCount, 0);
  });

  for (final status in [401, 408, 429]) {
    test('HTTP $status retains an offline status change', () async {
      adapter.status = status;
      await queue.enqueue(
        PendingAction(
          id: 'status',
          kind: PendingActionKind.status,
          path: 'orders/test/transition',
          method: 'PATCH',
          body: {'version': 1},
          createdAt: DateTime.now(),
        ),
      );
      await queue.flush();
      expect(queue.pendingCount, 1);
      final action = PendingAction.decode(
        Hive.box<String>(OfflineQueueService.boxName).get('status')!,
      );
      expect(action.ownerId, 'a');
      expect(adapter.calls.length, 1);
    });
  }

  test(
    'pending actions are not sent as the next courier or without a session',
    () async {
      connectivity.connected = false;
      await queue.enqueue(
        PendingAction(
          id: 'status',
          kind: PendingActionKind.status,
          path: 'orders/test/transition',
          body: {},
          createdAt: DateTime.now(),
        ),
      );
      api.accountId = 'b';
      connectivity.connected = true;
      await queue.flush();
      expect(adapter.calls, isEmpty);
      expect(queue.pendingCount, 1);
      api.accountId = 'a';
      api.token = null;
      await queue.flush();
      expect(adapter.calls, isEmpty);
      api.token = 'test-token';
      await queue.flush();
      expect(adapter.calls.length, 1);
    },
  );

  test('stopping while refresh is pending bars the ping retry', () async {
    queue.beginTracking('a');
    adapter.status = 401;
    final refreshing = Completer<bool>();
    api.onUnauthorized = () => refreshing.future;
    await queue.enqueue(ping('first', DateTime.now()));
    for (var i = 0; i < 20 && adapter.calls.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    queue.suspendTracking();
    final discard = queue.discardTracking();
    refreshing.complete(true);
    await discard;
    await queue.flush();
    expect(adapter.calls.length, 1);
    expect(queue.pendingPingCount, 0);
  });

  test(
    'account change during refresh cannot retry a queued write under a new token',
    () async {
      adapter.status = 401;
      final refreshing = Completer<bool>();
      api.onUnauthorized = () => refreshing.future;
      await queue.enqueue(
        PendingAction(
          id: 'status',
          kind: PendingActionKind.status,
          path: 'orders/test/transition',
          body: {},
          createdAt: DateTime.now(),
        ),
      );
      for (var i = 0; i < 20 && adapter.calls.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      api.accountId = 'b';
      api.token = 'other-test-token';
      refreshing.complete(true);
      await queue.flush();
      expect(adapter.calls.length, 1);
      expect(queue.pendingCount, 1);
    },
  );

  test(
    'restored identity precedes writes; explicit off shift survives reload',
    () async {
      SharedPreferences.setMockInitialValues({
        'courier_token': 'test-token',
        'courier_phone': 'a',
      });
      final prefs = await SharedPreferences.getInstance();
      final auth = AuthRepository(api: api, prefs: prefs);
      auth.restore();
      expect(api.accountId, 'a');
      final repository = CourierRepository(
        api: api,
        queue: queue,
        prefs: prefs,
        signedInPhone: () => auth.signedInPhone,
      );
      expect((await repository.me()).onShift, true);
      await repository.setShift(courierId: 'a', onShift: false);
      final restored = CourierRepository(
        api: api,
        queue: queue,
        prefs: prefs,
        signedInPhone: () => auth.signedInPhone,
      );
      expect((await restored.me()).onShift, false);
      final other = CourierRepository(
        api: api,
        queue: queue,
        prefs: prefs,
        signedInPhone: () => 'b',
      );
      expect((await other.me()).onShift, true);
    },
  );
}
