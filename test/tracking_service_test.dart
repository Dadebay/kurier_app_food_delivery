import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kurier_app/core/constants/app_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:kurier_app/core/models/pending_action.dart';
import 'package:kurier_app/core/network/api_client.dart';
import 'package:kurier_app/core/services/location_service.dart';
import 'package:kurier_app/core/services/offline_queue_service.dart';
import 'package:kurier_app/core/services/tracking_service.dart';
import 'support/location_fakes.dart';

class TestApi implements ApiClient {
  final events = <String>[];
  @override
  String? accountId = 'a';
  @override
  bool get authenticated => accountId != null;
  @override
  Future<Response<dynamic>> endTracking(String owner) async {
    events.add('delete');
    return Response(requestOptions: RequestOptions(), statusCode: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingQueue extends ChangeNotifier implements OfflineQueueService {
  final actions = <PendingAction>[];
  Completer<void>? sending;
  bool suspended = false;
  @override
  DateTime? get lastPingSentAt => null;
  @override
  void beginTracking(String owner) {
    suspended = false;
  }

  @override
  void suspendTracking() {
    suspended = true;
  }

  @override
  Future<void> discardTracking() async {
    await sending?.future;
    actions.clear();
  }

  @override
  Future<void> enqueue(PendingAction action) async {
    if (!suspended) actions.add(action);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'stationary fresh fixes are sent every 15 seconds without duplicate starts',
    () async {
      expect(AppConfig.trackingInterval, const Duration(seconds: 15));
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      );
      var at = now.subtract(const Duration(seconds: 30));
      final platform = FakeLocation();
      final location = LocationService(
        platform: platform,
        backgroundPermission: () async => false,
      );
      final queue = RecordingQueue();
      final api = TestApi();
      final tracking = TrackingService(
        location: location,
        queue: queue,
        api: api,
        interval: const Duration(milliseconds: 20),
      );
      await Future.wait([tracking.start('a'), tracking.start('a')]);
      platform.updates.add(measurement(at));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(queue.actions.length, 1);
      expect(platform.settings.length, 1);
      at = at.add(const Duration(seconds: 15));
      platform.updates.add(measurement(at));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(
        queue.actions.length,
        2,
        reason: 'same coordinates still produce a heartbeat',
      );
      expect(
        queue.actions.last.body['recordedAt'],
        at.toUtc().toIso8601String(),
      );
      expect(tracking.lastSentAt, null, reason: 'enqueued is not acknowledged');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(
        queue.actions.length,
        2,
        reason: 'never invent a new timestamp for the old fix',
      );
      await tracking.stop();
      expect(location.active, false);
      expect(queue.actions, isEmpty);
      expect(api.events, ['delete']);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(queue.actions, isEmpty);
      tracking.dispose();
      location.dispose();
      queue.dispose();
    },
  );

  test('the screen is held awake for the shift and released with it', () async {
    final wake = <bool>[];
    final platform = FakeLocation();
    final location = LocationService(
      platform: platform,
      backgroundPermission: () async => false,
    );
    final tracking = TrackingService(
      location: location,
      queue: RecordingQueue(),
      api: TestApi(),
      screenWake: (keepAwake) async => wake.add(keepAwake),
      interval: const Duration(milliseconds: 20),
    );

    await tracking.start('a');
    await Future<void>.delayed(Duration.zero);
    expect(wake, [true]);

    await tracking.stop();
    expect(
      wake,
      [true, false],
      reason: 'an off-shift courier gets their battery back',
    );
    tracking.dispose();
    location.dispose();
  });

  test('a phone that refuses the wakelock still runs the shift', () async {
    final platform = FakeLocation();
    final location = LocationService(
      platform: platform,
      backgroundPermission: () async => false,
    );
    final queue = RecordingQueue();
    final tracking = TrackingService(
      location: location,
      queue: queue,
      api: TestApi(),
      screenWake: (_) async => throw StateError('no wakelock here'),
      interval: const Duration(milliseconds: 20),
    );

    await tracking.start('a');
    platform.updates.add(
      measurement(
        DateTime.fromMillisecondsSinceEpoch(
          DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(queue.actions.length, 1, reason: 'reporting is what matters');
    await tracking.stop();
    tracking.dispose();
    location.dispose();
    queue.dispose();
  });

  test(
    'end shift waits for in-flight PUT before DELETE; restart waits for end',
    () async {
      final platform = FakeLocation();
      final location = LocationService(
        platform: platform,
        backgroundPermission: () async => false,
      );
      final queue = RecordingQueue()..sending = Completer<void>();
      final api = TestApi();
      final tracking = TrackingService(
        location: location,
        queue: queue,
        api: api,
        interval: const Duration(milliseconds: 20),
      );
      await tracking.start('a');
      final stopping = tracking.stop();
      final restarting = tracking.start('a');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(queue.suspended, true);
      expect(api.events, isEmpty);
      queue.sending!.complete();
      await stopping;
      await restarting;
      expect(api.events, ['delete']);
      expect(tracking.running, true);
      await tracking.stop();
      tracking.dispose();
      location.dispose();
      queue.dispose();
    },
  );
}
