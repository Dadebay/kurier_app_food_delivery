import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_config.dart';
import '../models/location_fix.dart';

/// What the courier reads on the ongoing notification Android requires for a
/// location foreground service. Supplied by the caller so the text follows the
/// app's own language instead of the plugin's English default.
typedef TrackingNotification = ({
  String channel,
  String title,
  String subtitle,
});

/// Keyless Android fused positioning, requesting high accuracy from the start.
/// High accuracy allows GNSS as well as network signals; it is not a promise
/// that a reading came from satellites or that a fix is available indoors.
class LocationService extends ChangeNotifier {
  LocationService({
    SharedPreferences? prefs,
    loc.Location? platform,
    DateTime Function()? now,
    Future<bool> Function()? backgroundPermission,
    Future<bool> Function()? backgroundStatus,
    Future<bool> Function()? batteryExemptionStatus,
    Future<bool> Function()? batteryExemptionRequest,
    TrackingNotification Function()? notification,
    this.fixTimeout = const Duration(seconds: 15),
    Duration preciseAttempt = defaultPreciseAttempt,
  }) : _prefs = prefs,
       _location = platform ?? loc.Location(),
       _now = now ?? DateTime.now,
       _backgroundPermission = backgroundPermission ?? _requestBackground,
       _backgroundStatus = backgroundStatus ?? _readBackground,
       _batteryExemptionStatus =
           batteryExemptionStatus ?? _readBatteryExemption,
       _batteryExemptionRequest =
           batteryExemptionRequest ?? _requestBatteryExemption,
       _notification = notification,
       // Clamped so a precise phase can never outlive the whole budget.
       preciseAttempt = preciseAttempt <= fixTimeout
           ? preciseAttempt
           : fixTimeout;

  final SharedPreferences? _prefs;
  final loc.Location _location;
  final DateTime Function() _now;
  final Future<bool> Function() _backgroundPermission;
  final Future<bool> Function() _backgroundStatus;
  final Future<bool> Function() _batteryExemptionStatus;
  final Future<bool> Function() _batteryExemptionRequest;
  final TrackingNotification Function()? _notification;
  final Duration fixTimeout;

  /// How long satellites get before an on-demand read drops to a
  /// network-based one.
  ///
  /// `LocationAccuracy.high` is the satellites-first mode, and indoors it can
  /// produce nothing at all — the courier is then invisible to the operator
  /// for the whole timeout. `balanced` places the phone from Wi-Fi and cell
  /// towers instead: hundreds of metres out at worst, but available through a
  /// roof. Precise is still tried first, so a courier outdoors — which is
  /// most of a shift — keeps exactly the accuracy they had before.
  static const Duration defaultPreciseAttempt = Duration(seconds: 6);

  /// This instance's satellite phase, clamped to [fixTimeout] so the tiers
  /// can never add up to more than the one budget.
  final Duration preciseAttempt;

  /// Verbose tracing for the indoor-location work. Unconditional rather than
  /// debug-only: the readings that matter come from a real phone inside a
  /// real building, which may be running a profile or release build.
  void _trace(String message) => dev.log(message, name: 'CourierLocation');
  StreamSubscription<loc.LocationData>? _sub;
  Future<bool>? _startInFlight;
  Future<LatLng?>? _fixInFlight;
  Future<loc.LocationData>? _platformRead;
  Future<void> _backgroundWork = Future.value();
  Future<void>? _stopInFlight;
  Completer<void> _cancel = Completer<void>();
  Completer<LatLng?>? _freshWaiter;
  Timer? _watchdog;
  LocationFix? _fix;
  String? _owner;
  String? _error;
  int _generation = 0;
  bool _active = false;
  bool _ready = false;
  bool _disposed = false;
  bool _backgroundGranted = false;
  bool _batteryUnrestricted = true;

  LocationFix? get fix => _fix;
  LatLng? get current => _fix?.point;
  DateTime? get currentAt => _fix?.recordedAt;
  Duration? get currentAge =>
      currentAt == null ? null : _now().difference(currentAt!);
  bool get isStale => _fix != null && !_fix!.isFresh(_now());
  double get heading => _fix?.heading ?? 0;
  double? get accuracy => _fix?.accuracy;
  double? get speed => _fix?.speed;
  bool get active => _active;
  bool get ready => _active && _ready;
  bool get backgroundGranted => _backgroundGranted;

  /// False only when the phone is known to be throttling this app. Aggressive
  /// OEM battery savers kill the tracking service mid-shift even with every
  /// location permission granted, so this is tracked separately from them.
  /// Optimistic by default: a platform that cannot answer is not a warning.
  bool get batteryUnrestricted => _batteryUnrestricted;
  String? get error => _error;

  /// Called before starting a shift. Never borrow another courier's last point.
  void setOwner(String owner) {
    if (_owner == owner) return;
    _owner = owner;
    _fix = null;
    final raw = _prefs?.getString('location.lastFix.$owner');
    if (raw == null) return;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      data['time'] = DateTime.parse(
        data['recordedAt'] as String,
      ).millisecondsSinceEpoch.toDouble();
      _fix = LocationFix.fromData(loc.LocationData.fromMap(data), _now());
    } catch (_) {
      // An invalid cache is never a live location.
    }
  }

  bool _valid(int generation) =>
      !_disposed && _active && generation == _generation;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> start() {
    if (_disposed) return Future.value(false);
    if (_startInFlight != null) return _startInFlight!;
    if (ready && _sub != null) return Future.value(true);
    _active = true;
    _cancel = Completer<void>();
    final generation = ++_generation;
    final future = _start(generation);
    _startInFlight = future;
    unawaited(
      future.then((_) {
        if (identical(_startInFlight, future)) _startInFlight = null;
      }),
    );
    return future;
  }

  Future<bool> _start(int generation) async {
    try {
      await _stopInFlight;
      if (!_valid(generation)) return false;
      var enabled = await _location.serviceEnabled();
      if (!_valid(generation)) return false;
      if (!enabled) enabled = await _location.requestService();
      if (!_valid(generation)) return false;
      if (!enabled) return _fail('location_service_off');
      var permission = await _location.hasPermission();
      if (!_valid(generation)) return false;
      if (permission == loc.PermissionStatus.denied) {
        permission = await _location.requestPermission();
      }
      if (!_valid(generation)) return false;
      if (permission != loc.PermissionStatus.granted &&
          permission != loc.PermissionStatus.grantedLimited) {
        return _fail('location_permission_denied');
      }
      // Do not wait for a balanced/network fix before requesting GNSS.
      await _location.changeSettings(
        accuracy: loc.LocationAccuracy.high,
        interval: 5000,
        distanceFilter: 0,
      );
      if (!_valid(generation)) return false;
      await _sub?.cancel();
      if (!_valid(generation)) return false;
      _sub = _location.onLocationChanged.listen(
        (data) {
          if (_valid(generation)) _accept(data);
        },
        onError: (Object error) {
          if (_valid(generation)) _fail('location_unavailable');
        },
      );
      _ready = true;
      _error = _fix?.isFresh(_now()) == true ? null : 'location_no_fix';
      _watchdog?.cancel();
      _watchdog = Timer.periodic(const Duration(seconds: 15), (_) {
        if (_valid(generation)) {
          _notify(); // Age must update even when the receiver is silent.
          if (_fix?.isFresh(_now()) != true) unawaited(currentOrFix());
        }
      });
      _notify();
      unawaited(_enableBackground(generation));
      unawaited(currentOrFix());
      return true;
    } catch (_) {
      if (_valid(generation)) return _fail('location_unavailable');
      return false;
    }
  }

  bool _fail(String reason) {
    _error = reason;
    _notify();
    return false;
  }

  void _accept(loc.LocationData data) {
    _trace(
      'reading · lat=${data.latitude} lng=${data.longitude} '
      'acc=${data.accuracy} time=${data.time}',
    );
    final fix = LocationFix.fromData(data, _now());
    if (fix == null) {
      // Coordinates out of range, NaN/infinite, an impossible accuracy radius
      // or a timestamp in the future — see LocationFix.fromData.
      _trace('reading rejected as invalid');
      return;
    }
    if (_fix != null && !fix.recordedAt.isAfter(_fix!.recordedAt)) {
      // The stream and an in-flight one-shot routinely deliver the same
      // measurement milliseconds apart, so this is usually a duplicate.
      final duplicate = fix.recordedAt == _fix!.recordedAt;
      _trace(
        'reading skipped — '
        '${duplicate ? 'duplicate of the one held' : 'older than the one held'}',
      );
      return;
    }
    _fix = fix;
    final fresh = fix.isFresh(_now());
    _trace(
      'reading stored: ${fix.point} acc=${fix.accuracy} '
      '${fresh ? 'FRESH' : 'stale (${_now().difference(fix.recordedAt).inSeconds}s old)'}',
    );
    _error = fresh ? null : 'location_no_fix';
    if (fix.isFresh(_now()) && _freshWaiter?.isCompleted == false) {
      _freshWaiter!.complete(fix.point);
    }
    final owner = _owner;
    if (_prefs != null && owner != null) {
      unawaited(
        _prefs.setString('location.lastFix.$owner', jsonEncode(fix.toJson())),
      );
    }
    _notify();
  }

  /// Returns only a fresh measurement. Cached points remain available to the
  /// map via [current], with their real age, but never suppress recovery.
  Future<LatLng?> currentOrFix() {
    if (!ready) return Future.value(null);
    if (_fix?.isFresh(_now()) == true) return Future.value(current);
    if (_fixInFlight != null) return _fixInFlight!;
    final future = _readFresh(_generation);
    _fixInFlight = future;
    unawaited(
      future.then((_) {
        if (identical(_fixInFlight, future)) _fixInFlight = null;
      }),
    );
    return future;
  }

  Future<LatLng?> _readFresh(int generation) async {
    final waiter = Completer<LatLng?>();
    _freshWaiter = waiter;
    // A stream update can satisfy this request even if getLocation is slow.
    final read = _platformRead ??= _location.getLocation();
    unawaited(
      read.then(
        (data) {
          if (identical(_platformRead, read)) _platformRead = null;
          if (_valid(generation)) _accept(data);
        },
        onError: (Object error) {
          if (identical(_platformRead, read)) _platformRead = null;
          if (_valid(generation)) _fail('location_unavailable');
        },
      ),
    );
    final elapsed = Stopwatch()..start();
    Duration remaining() => fixTimeout - elapsed.elapsed;

    try {
      // Indoors the satellite phase never produces anything, and after a
      // couple of rounds of proving that, spending a third of every budget
      // on it only keeps the courier off the map for longer. Once GNSS has
      // failed [_gnssFailuresBeforeSkip] times in a row, go straight to
      // network positioning and give it the whole budget; one satellite fix
      // resets this, so stepping outside restores the normal order.
      final skipGnss = _gnssFailures >= _gnssFailuresBeforeSkip;
      final precise = skipGnss
          ? Duration.zero
          : (preciseAttempt <= remaining() ? preciseAttempt : remaining());
      if (skipGnss) {
        _trace(
          'fix: skipping GNSS phase — $_gnssFailures indoor rounds in a row',
        );
      } else {
        _trace('fix: GNSS phase, waiting ${precise.inMilliseconds}ms');
      }
      var arrived = await _awaitFix(waiter, precise);
      if (arrived) {
        _gnssFailures = 0;
      } else if (!skipGnss) {
        _gnssFailures++;
      }

      if (!arrived && _valid(generation) && remaining() > Duration.zero) {
        // Indoors the satellite request above produces nothing at all, and
        // waiting the rest of the budget on it just leaves the courier
        // invisible for longer. Ask the same receiver to place the phone from
        // Wi-Fi and cell towers instead, with whatever time is left.
        _trace(
          'fix: no GNSS in ${precise.inMilliseconds}ms, trying network '
          'positioning with ${remaining().inMilliseconds}ms left',
        );
        await _applyAccuracy(loc.LocationAccuracy.balanced);
        if (_valid(generation)) {
          // A fresh one-shot: the read started above is bound to the old
          // accuracy setting and may never answer.
          final networkRead = _location.getLocation();
          unawaited(
            networkRead.then((data) {
              if (_valid(generation)) _accept(data);
            }, onError: (Object _) {}),
          );
          arrived = await _awaitFix(waiter, remaining());
        }

        // Unlike the customer app, this is not a one-shot service: the stream
        // opened by `_start` keeps feeding the operator for the rest of the
        // shift. Leaving it on `balanced` would quietly make every later
        // position coarse, so the downgrade is undone whether or not it
        // produced anything.
        await _applyAccuracy(loc.LocationAccuracy.high);
      }

      if (!arrived && _valid(generation)) _fail('location_no_fix');
    } finally {
      if (identical(_freshWaiter, waiter)) _freshWaiter = null;
    }

    final fresh = _valid(generation) && _fix?.isFresh(_now()) == true;
    _trace(
      'fix: done after ${elapsed.elapsedMilliseconds}ms — '
      '${fresh ? '$current acc=${_fix?.accuracy}' : 'no fresh fix'}',
    );
    return fresh ? current : null;
  }

  /// Waits up to [limit] for a fresh reading, reporting whether one arrived.
  /// A timeout is an expected outcome of each tier here, not a failure.
  /// How many satellite-only rounds may fail before the next attempt starts
  /// with network positioning instead. Two, so a single blocked round — a
  /// tunnel, a covered yard — does not change the order.
  static const _gnssFailuresBeforeSkip = 2;

  /// Consecutive rounds where the satellite phase produced nothing.
  int _gnssFailures = 0;

  Future<bool> _awaitFix(Completer<LatLng?> waiter, Duration limit) async {
    if (limit <= Duration.zero) return false;
    try {
      await Future.any([waiter.future, _cancel.future]).timeout(limit);
      return waiter.isCompleted;
    } on TimeoutException {
      return false;
    }
  }

  Future<void> _applyAccuracy(loc.LocationAccuracy accuracy) async {
    try {
      _trace('changeSettings(accuracy: ${accuracy.name})');
      await _location.changeSettings(
        accuracy: accuracy,
        interval: 5000,
        distanceFilter: 0,
      );
    } catch (error) {
      // Not every platform implementation accepts this; reads still work with
      // whatever settings are in force.
      _trace('changeSettings(${accuracy.name}) failed: $error');
    }
  }

  Future<void> retry() async {
    if (!_active) return;
    final stopping = stop();
    final generation = _generation;
    await stopping;
    if (!_disposed && generation == _generation) await start();
  }

  static Future<bool> _requestBackground() async {
    final status = await ph.Permission.locationAlways.status;
    return status.isGranted ||
        (await ph.Permission.locationAlways.request()).isGranted;
  }

  static Future<bool> _readBackground() async =>
      (await ph.Permission.locationAlways.status).isGranted;

  static Future<bool> _readBatteryExemption() async =>
      (await ph.Permission.ignoreBatteryOptimizations.status).isGranted;

  static Future<bool> _requestBatteryExemption() async =>
      (await ph.Permission.ignoreBatteryOptimizations.request()).isGranted;

  /// Replaces the plugin's English default ("Location background service
  /// running") with the courier's own language, before the service goes
  /// foreground so the first notification already reads correctly.
  ///
  /// Best effort on purpose: the notification is what the courier sees, not
  /// what keeps them on the map, so a platform that refuses to update it must
  /// never be the reason background tracking is reported as off.
  Future<void> _applyNotification() async {
    final text = _notification?.call();
    if (text == null) return;
    try {
      await _location.changeNotificationOptions(
        channelName: text.channel,
        title: text.title,
        subtitle: text.subtitle,
        onTapBringToFront: true,
      );
    } catch (_) {
      // Keeps the plugin's default text rather than losing the service.
    }
  }

  /// Re-applies the notification text after the courier switches language
  /// mid-shift. Does nothing while no service is running.
  Future<void> refreshNotification() async {
    if (!_active || !_backgroundGranted) return;
    await _applyNotification();
  }

  Future<void> _enableBackground(int generation, {bool prompt = true}) async {
    try {
      final granted = await (prompt
          ? _backgroundPermission()
          : _backgroundStatus());
      if (!_valid(generation)) return;
      _backgroundWork = _backgroundWork
          .then((_) async {
            if (!_valid(generation)) return;
            if (granted) await _applyNotification();
            if (!_valid(generation)) return;
            _backgroundGranted =
                granted && await _location.enableBackgroundMode(enable: true);
            _notify();
          })
          .catchError((Object error) {
            _backgroundGranted = false;
            _notify();
          });
      await _backgroundWork;
      unawaited(refreshBatteryExemption());
    } catch (_) {
      if (_valid(generation)) {
        _backgroundGranted = false;
        _notify();
      }
    }
  }

  /// Raises the permission request. Only for an explicit courier action.
  Future<void> refreshBackgroundPermission() async {
    if (!_active) return;
    await _enableBackground(_generation);
  }

  /// Re-reads the grant without asking for it, and picks up background mode
  /// if the courier turned it on in system settings. Safe on every resume:
  /// a resume is not a request, and a dialog on every return to the app
  /// would be its own kind of broken.
  Future<void> refreshBackgroundStatus() async {
    if (!_active || _backgroundGranted) return;
    await _enableBackground(_generation, prompt: false);
  }

  /// Reads the exemption without prompting — safe to call on every resume.
  Future<void> refreshBatteryExemption() async {
    try {
      final unrestricted = await _batteryExemptionStatus();
      if (_disposed || unrestricted == _batteryUnrestricted) return;
      _batteryUnrestricted = unrestricted;
      _notify();
    } catch (_) {
      // A platform without the concept is not a restricted platform.
    }
  }

  /// Raises the system "allow background activity" dialog. Only ever called
  /// from an explicit courier action, never during startup.
  Future<bool> requestBatteryExemption() async {
    try {
      final granted = await _batteryExemptionRequest();
      if (_disposed) return granted;
      _batteryUnrestricted = granted;
      _notify();
      return granted;
    } catch (_) {
      return false;
    }
  }

  /// Asks for the always-on grant outside a running shift, so the courier can
  /// be stopped at the door rather than discovering mid-delivery that nothing
  /// was being reported. Unlike [refreshBackgroundPermission] this reports the
  /// permission alone and never claims the service is running in background
  /// mode — [backgroundGranted] still means exactly that.
  Future<bool> ensureBackgroundPermission() async {
    try {
      return await _backgroundPermission();
    } catch (_) {
      return false;
    }
  }

  Future<bool> openBackgroundPermissionSettings() => ph.openAppSettings();

  Future<void> stop() {
    _active = false;
    _ready = false;
    _generation++;
    if (!_cancel.isCompleted) _cancel.complete();
    _watchdog?.cancel();
    _watchdog = null;
    _startInFlight = null;
    _fixInFlight = null;
    _error = null;
    final sub = _sub;
    _sub = null;
    _backgroundWork = _backgroundWork.then((_) async {
      try {
        await _location.enableBackgroundMode(enable: false);
      } catch (_) {
        /* shutting down */
      }
      _backgroundGranted = false;
    });
    final future = Future.wait<void>([
      if (sub != null) sub.cancel(),
      _backgroundWork,
    ]).then((_) {});
    _stopInFlight = future;
    _notify();
    return future;
  }

  static double metersBetween(LatLng a, LatLng b) =>
      const Distance().as(LengthUnit.Meter, a, b);
  static double kmBetween(LatLng a, LatLng b) =>
      const Distance().as(LengthUnit.Kilometer, a, b);
  static const LatLng fallbackCenter = LatLng(
    AppConfig.defaultLat,
    AppConfig.defaultLng,
  );

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
