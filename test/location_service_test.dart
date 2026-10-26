import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:location/location.dart' as loc;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kurier_app/core/models/location_fix.dart';
import 'package:kurier_app/core/services/location_service.dart';

import 'support/location_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 9, 13, 12);

  test('measurements retain platform time and reject invalid data', () {
    final at = now.subtract(const Duration(minutes: 2));
    final fix = LocationFix.fromData(measurement(at), now)!;
    expect(fix.recordedAt, at);
    expect(fix.isFresh(now), false);
    expect(fix.toJson()['recordedAt'], at.toIso8601String());
    expect(LocationFix.fromData(measurement(now, lat: double.nan), now), null);
    expect(LocationFix.fromData(measurement(now, lng: 181), now), null);
    expect(LocationFix.fromData(measurement(now, accuracy: 6000), now), null);
    expect(
      LocationFix.fromData(
        measurement(now.add(const Duration(seconds: 1))),
        now,
      ),
      null,
    );
    expect(
      LocationFix.fromData(
        loc.LocationData.fromMap({'latitude': 37.0, 'longitude': 58.0}),
        now,
      ),
      null,
    );
    expect(
      LocationFix.fromData(
        measurement(now, speed: -1, heading: -1),
        now,
      )!.toJson(),
      isNot(contains('speed')),
    );
  });

  test(
    'cold start requests high accuracy and accepts a first stream fix',
    () async {
      final platform = FakeLocation();
      final service = LocationService(
        platform: platform,
        now: () => now,
        backgroundPermission: () async => false,
      );
      expect(await service.start(), true);
      expect(platform.settings, [loc.LocationAccuracy.high]);
      expect(platform.distances, [0]);
      final first = service.currentOrFix();
      final second = service.currentOrFix();
      expect(identical(first, second), true);
      expect(platform.reads, 1);
      platform.updates.add(measurement(now));
      expect(await first, isNotNull);
      expect(service.currentAt, now);
      expect(service.error, null);
      await service.stop();
      service.dispose();
    },
  );

  test(
    'stale saved point does not block recovery or become a fresh fix',
    () async {
      final at = now.subtract(const Duration(hours: 2));
      SharedPreferences.setMockInitialValues({
        'location.lastFix.a': jsonEncode({
          'latitude': 37.0,
          'longitude': 58.0,
          'recordedAt': at.toIso8601String(),
          'accuracy': 100.0,
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final platform = FakeLocation();
      final service = LocationService(
        prefs: prefs,
        fixTimeout: const Duration(milliseconds: 10),
        platform: platform,
        now: () => now,
        backgroundPermission: () async => false,
      );
      service.setOwner('a');
      expect(service.currentAt, at);
      await service.start();
      final waiting = service.currentOrFix();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await waiting, null);
      expect(service.currentAt, at);
      expect(service.isStale, true);
      expect(
        platform.reads,
        1,
        reason: 'do not stack native reads after a timeout',
      );
      platform.updates.add(measurement(now));
      expect(await service.currentOrFix(), isNotNull);
      platform.updates.add(measurement(at, lat: 30));
      expect(
        service.currentAt,
        now,
        reason: 'ignore out-of-order batched fixes',
      );
      await service.stop();
      service.setOwner('b');
      expect(service.current, null);
      service.dispose();
    },
  );

  test(
    'stop cancels a pending fix and ignores late native completion',
    () async {
      final platform = FakeLocation();
      final permission = Completer<bool>();
      final service = LocationService(
        platform: platform,
        now: () => now,
        backgroundPermission: () => permission.future,
      );
      await service.start();
      final pending = service.currentOrFix();
      await service.stop();
      expect(await pending, null);
      platform.reading.complete(measurement(now));
      permission.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(service.current, null);
      expect(service.ready, false);
      expect(platform.background, isNot(contains(true)));
      expect(await service.currentOrFix(), null);
      service.dispose();
    },
  );

  test(
    'the shift notification is localised before the service goes foreground',
    () async {
      final platform = FakeLocation();
      final service = LocationService(
        platform: platform,
        now: () => now,
        backgroundPermission: () async => true,
        batteryExemptionStatus: () async => true,
        notification: () => (
          channel: 'Nobat yzarlamasy',
          title: 'A7-TAGAM · Siz nobatdasyňyz',
          subtitle: 'Ýerleşişiňiz operatora ugradylýar.',
        ),
      );
      await service.start();
      await Future<void>.delayed(Duration.zero);

      // Ordering is the point: the plugin builds its notification when
      // startForeground runs, so English default text would stick if the
      // options arrived afterwards.
      expect(platform.notifications.single['title'], contains('A7-TAGAM'));
      expect(platform.notifications.single['channelName'], 'Nobat yzarlamasy');
      expect(platform.background, [true]);
      expect(service.backgroundGranted, true);
      service.dispose();
    },
  );

  test(
    'an indoor read drops to network positioning and puts GNSS back',
    () async {
      // Indoors the satellite request produces nothing, and waiting the whole
      // budget on it leaves the courier invisible to the operator. The read
      // should try precise first, fall back to Wi-Fi/cell, and — because the
      // stream keeps running for the rest of the shift — restore the precise
      // setting afterwards.
      final platform = FakeLocation();
      final service = LocationService(
        platform: platform,
        now: () => now,
        backgroundPermission: () async => false,
        fixTimeout: const Duration(milliseconds: 200),
        preciseAttempt: const Duration(milliseconds: 40),
      );

      expect(await service.start(), true);
      expect(platform.settings, [loc.LocationAccuracy.high]);

      // Nothing ever answers, so this resolves when the budget runs out —
      // which is the point: the read is bounded rather than hanging.
      expect(await service.currentOrFix(), null);
      expect(service.error, 'location_no_fix');

      expect(
        platform.settings,
        [
          loc.LocationAccuracy.high,
          loc.LocationAccuracy.balanced,
          loc.LocationAccuracy.high,
        ],
        reason: 'precise, then the network tier, then precise again',
      );
      expect(platform.reads, 2, reason: 'the network tier needs its own read');
    },
  );

  test('a fix inside the precise phase never downgrades accuracy', () async {
    // Outdoors — which is most of a shift — the behaviour must be exactly
    // what it was before the indoor tier existed.
    final platform = FakeLocation();
    final service = LocationService(
      platform: platform,
      now: () => now,
      backgroundPermission: () async => false,
      fixTimeout: const Duration(milliseconds: 400),
      preciseAttempt: const Duration(milliseconds: 200),
    );

    expect(await service.start(), true);
    final waiting = service.currentOrFix();
    platform.updates.add(measurement(now));

    expect(await waiting, isNotNull);
    expect(
      platform.settings,
      [loc.LocationAccuracy.high],
      reason: 'a satellite fix in time must not touch the accuracy setting',
    );
  });

  test('a denied always-on grant never raises a notification', () async {
    final platform = FakeLocation();
    final service = LocationService(
      platform: platform,
      now: () => now,
      backgroundPermission: () async => false,
      batteryExemptionStatus: () async => true,
      notification: () => (channel: 'c', title: 't', subtitle: 's'),
    );
    await service.start();
    await Future<void>.delayed(Duration.zero);
    expect(platform.notifications, isEmpty);
    expect(service.backgroundGranted, false);
    service.dispose();
  });

  test('a resume re-reads the grant without ever prompting', () async {
    final platform = FakeLocation();
    var prompts = 0;
    var granted = false;
    final service = LocationService(
      platform: platform,
      now: () => now,
      backgroundPermission: () async {
        prompts++;
        return granted;
      },
      backgroundStatus: () async => granted,
      batteryExemptionStatus: () async => true,
    );
    await service.start();
    await Future<void>.delayed(Duration.zero);
    expect(prompts, 1, reason: 'the shift itself may ask once');
    expect(service.backgroundGranted, false);

    // The courier flips "Allow all the time" in system settings and returns.
    granted = true;
    await service.refreshBackgroundStatus();
    await Future<void>.delayed(Duration.zero);
    expect(prompts, 1, reason: 'a resume must never raise a dialog');
    expect(service.backgroundGranted, true);
    expect(platform.background, [true]);

    // Already running in background mode: nothing left to re-read.
    await service.refreshBackgroundStatus();
    expect(platform.background, [true]);
    service.dispose();
  });

  test(
    'battery throttling is reported without prompting the courier',
    () async {
      final platform = FakeLocation();
      var prompts = 0;
      final service = LocationService(
        platform: platform,
        now: () => now,
        backgroundPermission: () async => true,
        batteryExemptionStatus: () async => false,
        batteryExemptionRequest: () async {
          prompts++;
          return true;
        },
      );
      await service.start();
      await Future<void>.delayed(Duration.zero);
      expect(service.batteryUnrestricted, false);
      expect(prompts, 0, reason: 'startup must never raise a system dialog');

      expect(await service.requestBatteryExemption(), true);
      expect(prompts, 1);
      expect(service.batteryUnrestricted, true);
      service.dispose();
    },
  );

  test(
    'stop during permission/service startup cannot start a late stream',
    () async {
      final enabled = Completer<bool>();
      final platform = FakeLocation()..enabledResult = enabled.future;
      final service = LocationService(
        platform: platform,
        backgroundPermission: () async => false,
      );
      final starting = service.start();
      await Future<void>.delayed(Duration.zero);
      await service.stop();
      enabled.complete(true);
      expect(await starting, false);
      expect(platform.settings, isEmpty);
      expect(service.ready, false);
      service.dispose();
    },
  );
}
