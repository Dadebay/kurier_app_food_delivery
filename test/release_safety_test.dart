import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart' as hive_ce;
import 'package:hive_flutter/hive_flutter.dart' as hive;
import 'package:a7_tagam_kurier/core/data/auth_repository.dart';
import 'package:a7_tagam_kurier/core/models/order.dart';
import 'package:a7_tagam_kurier/core/models/order_status.dart';
import 'package:a7_tagam_kurier/core/models/pending_action.dart';
import 'package:a7_tagam_kurier/core/network/api_client.dart';
import 'package:a7_tagam_kurier/core/services/connectivity_service.dart';
import 'package:a7_tagam_kurier/core/services/offline_queue_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ReplyAdapter implements HttpClientAdapter {
  _ReplyAdapter(this.statuses, {this.failWithConnectionError = false});

  final List<int> statuses;
  final bool failWithConnectionError;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (failWithConnectionError) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    final status = statuses.removeAt(0);
    return ResponseBody.fromBytes(
      utf8.encode('{}'),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('release_safety_test');
    hive_ce.Hive.init(tempDir.path);
    hive.Hive.init(tempDir.path);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await hive.Hive.deleteFromDisk();
    await hive_ce.Hive.deleteFromDisk();
    tempDir.deleteSync(recursive: true);
  });

  test('rate-limited status stays queued and succeeds on retry', () async {
    final api = ApiClient();
    api.raw.httpClientAdapter = _ReplyAdapter([429, 200]);
    final connectivity = ConnectivityService.test();
    final queue = OfflineQueueService(api: api, connectivity: connectivity);
    await queue.init();
    final action = PendingAction(
      id: 'status-order-1',
      kind: PendingActionKind.status,
      path: 'orders/order-1/transition',
      method: 'PATCH',
      body: {'status': 'DELIVERED', 'version': 1},
      createdAt: DateTime.now(),
    );
    await hive.Hive.box<String>(
      OfflineQueueService.boxName,
    ).put(action.id, action.encode());

    await queue.flush();
    expect(queue.pendingCount, 1);
    expect(
      PendingAction.decode(
        hive.Hive.box<String>(OfflineQueueService.boxName).get(action.id)!,
      ).attempts,
      1,
    );

    await queue.flush();
    expect(queue.pendingCount, 0);
    queue.dispose();
    connectivity.dispose();
    await api.clearCache(RegExp('.*'));
  });

  test('offline sign-out clears the local session', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('courier_token', 'test-access-token');
    await prefs.setString('courier_refresh_token', 'test-refresh-token');
    await prefs.setString('courier_phone', '+99300000000');
    final api = ApiClient();
    api.raw.httpClientAdapter = _ReplyAdapter(
      [],
      failWithConnectionError: true,
    );
    final auth = AuthRepository(api: api, prefs: prefs);
    auth.restore();

    await auth.signOut();

    expect(auth.isSignedIn, isFalse);
    expect(auth.signedInPhone, isNull);
    await api.clearCache(RegExp('.*'));
  });

  test('refresh rate limit does not erase a valid session', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('courier_token', 'test-access-token');
    await prefs.setString('courier_refresh_token', 'test-refresh-token');
    final api = ApiClient();
    api.raw.httpClientAdapter = _ReplyAdapter([429]);
    final auth = AuthRepository(api: api, prefs: prefs);
    auth.restore();

    expect(await auth.refreshSession(), isFalse);
    expect(auth.isSignedIn, isTrue);
    await api.clearCache(RegExp('.*'));
  });

  test('unknown backend order status is never shown as assigned', () {
    expect(() => OrderStatus.fromWire('PAID'), throwsFormatException);
    expect(() => OrderStatus.fromWire(null), throwsFormatException);
  });

  test('an order without an id cannot be sent to a fabricated endpoint', () {
    expect(() => DeliveryOrder.fromJson({'number': 1}), throwsFormatException);
  });
}
