import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_config.dart';

/// Wraps the platform GPS.
///
/// The courier's marker on the map follows this stream continuously, while the
/// *server* only hears about it every few minutes (see [TrackingService]) —
/// smooth map, cheap data plan.
class LocationService extends ChangeNotifier {
  LocationService({SharedPreferences? prefs}) : _prefs = prefs {
    _restoreLastFix();
  }

  static const String _lastFixKey = 'location.lastFix';

  final SharedPreferences? _prefs;
  final loc.Location _location = loc.Location();

  StreamSubscription<loc.LocationData>? _sub;
  Future<bool>? _startInFlight;
  Completer<LatLng>? _firstFixCompleter;
  Timer? _watchdog;
  bool _highAccuracy = false;

  /// Optional last resort, wired in main.dart: resolves a coarse position from
  /// the Wi-Fi around the phone through our own server. Left null the service
  /// simply behaves as before.
  Future<LatLng?> Function()? networkFallback;

  /// How long the high-accuracy stream may stay silent before the service
  /// falls back. Satellite fixes stop indoors, in tunnels and between tall
  /// buildings; Android's balanced mode keeps answering there because it also
  /// uses Wi-Fi and cell towers.
  static const Duration _satelliteSilence = Duration(seconds: 45);

  LatLng? _current;
  DateTime? _currentAt;
  double _heading = 0;
  double? _accuracy;
  double? _speed;
  bool _permissionGranted = false;
  bool _backgroundGranted = false;
  bool _serviceEnabled = false;
  String? _error;

  LatLng? get current => _current;

  /// When the newest accepted fix arrived. The courier screen uses it to say
  /// how old the marker is instead of showing a stale point as if it were live.
  DateTime? get currentAt => _currentAt;

  Duration? get currentAge =>
      _currentAt == null ? null : DateTime.now().difference(_currentAt!);

  /// False while the service is running on Wi-Fi/cell positioning because the
  /// satellites went quiet.
  bool get onSatellites => _highAccuracy;

  /// True when [current] is a remembered point rather than a live reading —
  /// the courier walked into a building, or the app was opened there and the
  /// receiver has not locked on yet.
  bool get isStale {
    final age = currentAge;
    return age != null && age > const Duration(minutes: 1);
  }

  /// Reading kept across restarts. Opening the app inside a building used to
  /// leave the operator with no position at all; the last real one, carrying
  /// its own age, is far more useful than an empty map.
  void _restoreLastFix() {
    final raw = _prefs?.getString(_lastFixKey);
    if (raw == null) return;
    final parts = raw.split(',');
    if (parts.length != 3) return;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    final at = DateTime.tryParse(parts[2]);
    if (lat == null || lng == null || at == null) return;
    if (!_isValidCoordinate(lat, lng)) return;
    _current = LatLng(lat, lng);
    _currentAt = at;
    _trace('restored last known fix $_current from $at');
  }

  void _rememberLastFix() {
    final point = _current;
    final at = _currentAt;
    if (point == null || at == null) return;
    unawaited(
      Future<void>.sync(
        () => _prefs?.setString(
          _lastFixKey,
          '${point.latitude},${point.longitude},${at.toIso8601String()}',
        ),
      ),
    );
  }

  /// Degrees clockwise from north — rotates the car marker.
  double get heading => _heading;

  /// Horizontal accuracy in meters, when the platform reports one.
  double? get accuracy => _accuracy;

  /// Ground speed in m/s, when the platform reports one.
  double? get speed => _speed;

  bool get ready => _permissionGranted && _serviceEnabled;

  /// Whether the courier granted "all the time" location. Without it the
  /// marker stops moving as soon as the phone goes into a pocket.
  bool get backgroundGranted => _backgroundGranted;
  String? get error => _error;

  void _trace(
    String message, {
    String color = '\x1B[36m',
    String marker = '🔵',
  }) {
    if (kDebugMode) {
      debugPrint('$color$marker [CourierLocation] $message\x1B[0m');
    }
  }

  void _success(String message) =>
      _trace(message, color: '\x1B[32m', marker: '✅');

  void _warning(String message) =>
      _trace(message, color: '\x1B[33m', marker: '⚠️');

  void _danger(String message) =>
      _trace(message, color: '\x1B[31m', marker: '❌');

  /// Asks for the GPS service and the permission, then starts streaming.
  /// Safe to call more than once.
  Future<bool> start() {
    final inFlight = _startInFlight;
    if (inFlight != null) {
      _trace('start reuses the in-flight request');
      return inFlight;
    }
    if (ready && _sub != null) {
      _trace('start reuses the active location stream current=$_current');
      return Future.value(true);
    }

    final future = _start();
    _startInFlight = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_startInFlight, future)) _startInFlight = null;
      }),
    );
    return future;
  }

  Future<bool> _start() async {
    _trace(
      'start current=$_current service=$_serviceEnabled '
      'foreground=$_permissionGranted background=$_backgroundGranted',
    );
    try {
      _serviceEnabled = await _location.serviceEnabled();
      _trace('serviceEnabled=$_serviceEnabled');
      if (!_serviceEnabled) {
        _trace('requesting location service');
        _serviceEnabled = await _location.requestService();
        _trace('requestService result=$_serviceEnabled');
        if (!_serviceEnabled) {
          _fail('location_service_off');
          return false;
        }
      }

      var permission = await _location.hasPermission();
      _trace('foreground permission before request=$permission');
      if (permission == loc.PermissionStatus.denied) {
        permission = await _location.requestPermission();
        _trace('foreground permission after request=$permission');
      }
      _permissionGranted =
          permission == loc.PermissionStatus.granted ||
          permission == loc.PermissionStatus.grantedLimited;

      if (!_permissionGranted) {
        _fail('location_permission_denied');
        return false;
      }
      _trace('foreground permission accepted');

      await _location.changeSettings(
        // Obtain the first marker from Android's fused network/Wi-Fi provider
        // when satellite GPS has no fix (common indoors), then promote to high
        // accuracy below for actual driving.
        accuracy: loc.LocationAccuracy.balanced,
        interval: 5000,
        distanceFilter: 10,
      );
      _trace('GPS settings applied: balanced first fix, 5s, 10m');

      // Start foreground tracking before Android's optional "always allow"
      // flow. Some vendor ROMs keep that settings flow pending for a long
      // time; waiting for it used to leave [current] null and therefore hid
      // the courier marker even while the map screen was already visible.
      if (_sub == null) {
        _sub = _location.onLocationChanged.listen(
          _onData,
          onError: (Object error, StackTrace stackTrace) {
            _danger('location stream error=$error');
            dev.log(
              'location stream failed',
              name: 'LocationService',
              error: error,
              stackTrace: stackTrace,
            );
          },
        );
        _trace('location stream subscribed');
      }
      // A restored point counts as "have something to show", never as "done
      // looking" — otherwise the app would sit on yesterday's position and
      // never reach for a live one.
      if (_current == null || isStale) {
        _trace('waiting for initial GPS stream fix (stale=$isStale)');
        await _waitForFirstFix();
      }

      if (_current != null && !isStale) {
        await _promote();
      } else {
        // The stream said nothing within the timeout. A one-shot read often
        // still answers, because it may hand back a position the system
        // already had from another app or from Wi-Fi/cell.
        await _oneShotFallback();
      }
      _startWatchdog();

      // Optional background permission must never hold the foreground map.
      unawaited(_enableBackgroundMode());
      if (_current == null) {
        _warning(
          'start complete but courier location is still null; '
          'background=$_backgroundGranted',
        );
      } else {
        _success(
          'start complete current=$_current background=$_backgroundGranted',
        );
      }

      _error = null;
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      dev.log(
        'location start failed',
        name: 'LocationService',
        error: error,
        stackTrace: stackTrace,
      );
      _fail('$error');
      return false;
    }
  }

  /// Android 11+ silently denies any permission request that bundles
  /// ACCESS_BACKGROUND_LOCATION together with the foreground one — the dialog
  /// only ever offers "While using the app", so the background grant comes
  /// back denied no matter what the courier taps. `location` asks for both in
  /// a single call, which is why enableBackgroundMode() reported
  /// PERMISSION_DENIED even right after the courier pressed Allow.
  ///
  /// The always-on grant has to be asked for on its own, once the foreground
  /// one is already in place; permission_handler routes that to the system
  /// page where "Allow all the time" actually lives.
  Future<void> _enableBackgroundMode() async {
    try {
      _backgroundGranted = await _ensureBackgroundPermission();
      if (_backgroundGranted) {
        _success('background permission granted=true');
      } else {
        _warning('background permission granted=false');
      }
      if (!_backgroundGranted) {
        // Not fatal — foreground tracking still works.
        dev.log(
          'background location not granted, foreground tracking only',
          name: 'LocationService',
        );
        return;
      }
      await _location.enableBackgroundMode(enable: true);
      _success('background mode enabled');
    } catch (error) {
      _backgroundGranted = false;
      dev.log('background mode unavailable: $error', name: 'LocationService');
    }
  }

  Future<bool> _ensureBackgroundPermission() async {
    final status = await ph.Permission.locationAlways.status;
    _trace('background permission before request=$status');
    if (status.isGranted) return true;
    // Permanently denied cannot be re-asked in-app; the courier has to flip
    // the switch in settings (see [openBackgroundPermissionSettings]).
    if (status.isPermanentlyDenied) return false;
    final requested = await ph.Permission.locationAlways.request();
    _trace('background permission after request=$requested');
    return requested.isGranted;
  }

  /// Opens the system page holding the "Allow all the time" switch. On
  /// Android 11+ that switch cannot be reached from an in-app dialog at all.
  Future<void> openBackgroundPermissionSettings() => ph.openAppSettings();

  /// Re-checks the always-on grant after the courier comes back from
  /// settings, and starts background reporting if it was given.
  Future<bool> refreshBackgroundPermission() async {
    await _enableBackgroundMode();
    notifyListeners();
    return _backgroundGranted;
  }

  /// The `location` plugin has been seen to emit NaN lat/lng on some devices
  /// while the GPS hasn't locked yet — a value that is not null and so slips
  /// straight past the usual null check, but crashes flutter_map's camera
  /// math the moment it becomes the courier point (bounds computations assert
  /// `-90 <= latitude <= 90`, which NaN comparisons always fail).
  static bool _isValidCoordinate(double lat, double lng) =>
      lat.isFinite && lng.isFinite && lat.abs() <= 90 && lng.abs() <= 180;

  Future<LatLng?> _waitForFirstFix() async {
    if (_current != null) return _current;
    final completer = _firstFixCompleter ??= Completer<LatLng>();
    try {
      return await completer.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      _warning('initial GPS stream fix timed out after 10s');
      return null;
    }
  }

  /// Satellite mode: best precision while the courier is actually driving.
  Future<void> _promote() async {
    if (_highAccuracy) return;
    await _location.changeSettings(
      accuracy: loc.LocationAccuracy.high,
      interval: 5000,
      distanceFilter: 10,
    );
    _highAccuracy = true;
    _success('GPS promoted to high accuracy');
  }

  /// Wi-Fi/cell mode: coarser, but it answers where satellites do not. This is
  /// the "other method" for tunnels, basements and covered yards — Android's
  /// own fused provider does the lookup, so no external locator service is
  /// involved.
  Future<void> _demote(String reason) async {
    if (!_highAccuracy) return;
    await _location.changeSettings(
      accuracy: loc.LocationAccuracy.balanced,
      interval: 5000,
      distanceFilter: 10,
    );
    _highAccuracy = false;
    _warning('GPS fell back to Wi-Fi/cell positioning: $reason');
    notifyListeners();
  }

  /// Watches for a stream that has gone quiet and switches modes accordingly,
  /// so a courier who walks into a building keeps producing positions.
  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 15), (_) {
      final at = _currentAt;
      if (at == null) return;
      final silence = DateTime.now().difference(at);
      if (_highAccuracy && silence > _satelliteSilence) {
        unawaited(_demote('no fix for ${silence.inSeconds}s'));
      }
    });
  }

  /// Last resort for the very first fix: ask once, with a short timeout, and
  /// accept whatever the system already knows.
  Future<void> _oneShotFallback() async {
    try {
      _trace('requesting one-shot fix after stream timeout');
      final data = await _location.getLocation().timeout(
        const Duration(seconds: 8),
      );
      _onData(data);
      if (_current != null) {
        _success('one-shot fallback produced $_current');
      }
    } on TimeoutException {
      _warning('one-shot fallback timed out');
    } catch (error) {
      _warning('one-shot fallback failed: $error');
    }
    if (_current == null) await _networkFallback();
  }

  /// The phone knows nothing about where it is, but it can still see networks.
  /// A fix hundreds of metres wide beats leaving a hole in the courier's track.
  Future<void> _networkFallback() async {
    final resolve = networkFallback;
    if (resolve == null) return;
    try {
      final point = await resolve();
      if (point == null ||
          !_isValidCoordinate(point.latitude, point.longitude)) {
        _warning('network positioning returned nothing');
        return;
      }
      _current = point;
      _currentAt = DateTime.now();
      _rememberLastFix();
      final firstFix = _firstFixCompleter;
      if (firstFix != null && !firstFix.isCompleted) firstFix.complete(point);
      _success('network positioning produced $point');
      notifyListeners();
    } catch (error) {
      _warning('network positioning failed: $error');
    }
  }

  void _onData(loc.LocationData data) {
    final lat = data.latitude;
    final lng = data.longitude;
    if (lat == null || lng == null || !_isValidCoordinate(lat, lng)) {
      _warning(
        'rejected GPS value lat=$lat lng=$lng accuracy=${data.accuracy}',
      );
      return;
    }

    _current = LatLng(lat, lng);
    _currentAt = DateTime.now();
    // A satellite fix came back while running on Wi-Fi/cell — go precise again.
    final accuracy = data.accuracy;
    if (!_highAccuracy && accuracy != null && accuracy > 0 && accuracy <= 30) {
      unawaited(_promote());
    }
    final firstFix = _firstFixCompleter;
    if (firstFix != null && !firstFix.isCompleted) firstFix.complete(_current);
    final heading = data.heading;
    if (heading != null && heading >= 0) _heading = heading;
    _accuracy = data.accuracy;
    _speed = data.speed;
    _rememberLastFix();
    _success(
      'GPS accepted lat=$lat lng=$lng accuracy=$_accuracy '
      'heading=$_heading speed=$_speed',
    );
    notifyListeners();
  }

  void _fail(String reason) {
    _error = reason;
    _danger('failure=$reason');
    dev.log(reason, name: 'LocationService');
    notifyListeners();
  }

  /// One-off fix, used before the stream has produced anything.
  Future<LatLng?> currentOrFix() async {
    if (_current != null) {
      _trace('currentOrFix uses cached point=$_current');
      return _current;
    }
    if (!ready && !await start()) {
      _danger('currentOrFix stopped because start failed');
      return null;
    }
    final point = await _waitForFirstFix();
    if (point != null) {
      _trace('currentOrFix stream result=$point');
      return point;
    }
    // Nothing from the stream: try the system's own answer once more before
    // reporting no position at all. A skipped ping leaves a hole in the
    // courier's track; a Wi-Fi/cell fix is worth far more than nothing.
    await _oneShotFallback();
    _trace('currentOrFix fallback result=$_current');
    return _current;
  }

  /// Metres between two points, on the same sphere model flutter_map uses.
  static double metersBetween(LatLng a, LatLng b) =>
      const Distance().as(LengthUnit.Meter, a, b);

  static double kmBetween(LatLng a, LatLng b) =>
      const Distance().as(LengthUnit.Kilometer, a, b);

  /// Ashgabat centre — where the map sits until the first fix lands.
  static const LatLng fallbackCenter = LatLng(
    AppConfig.defaultLat,
    AppConfig.defaultLng,
  );

  Future<void> stop() async {
    _watchdog?.cancel();
    _watchdog = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _location.enableBackgroundMode(enable: false);
    } catch (_) {
      // Ignore — we are shutting down anyway.
    }
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
