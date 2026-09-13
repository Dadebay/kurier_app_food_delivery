import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent, application-only traffic accounting for the courier app.
///
/// Android's [TrafficStats] reports the bytes carried by this app's UID. That
/// includes the map, API, background location pings and push traffic, but not
/// any other application on the courier's phone. The Android counter resets on
/// reboot, so this service stores each observed difference locally.
class DataUsageService extends ChangeNotifier {
  DataUsageService(this._prefs, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const MethodChannel _channel = MethodChannel('a7_tagam_kurier/usage');

  static const int bytesPerMegabyte = 1024 * 1024;
  static const int bytesPerGigabyte = 1024 * bytesPerMegabyte;

  static const _mobileBytesKey = 'data_usage_mobile_bytes';
  static const _wifiBytesKey = 'data_usage_wifi_bytes';
  static const _lastRxKey = 'data_usage_last_rx';
  static const _lastTxKey = 'data_usage_last_tx';
  static const _startedAtKey = 'data_usage_started_at';
  static const _usageDayKey = 'data_usage_day';
  static const _historyKey = 'data_usage_history';

  /// How many past days are kept. A month of daily figures is what makes a
  /// courier's bill explainable ("the 14th was the heavy day"); older than
  /// that nobody acts on, and it would grow without end.
  static const int historyDays = 30;

  final SharedPreferences _prefs;
  final DateTime Function() _now;

  Timer? _timer;
  bool _sampling = false;
  bool _supported = true;

  bool get isSupported => _supported;
  int get mobileBytes =>
      _isCurrentDay ? _prefs.getInt(_mobileBytesKey) ?? 0 : 0;
  int get wifiBytes => _isCurrentDay ? _prefs.getInt(_wifiBytesKey) ?? 0 : 0;
  int get totalBytes => mobileBytes + wifiBytes;

  bool get _isCurrentDay => _prefs.getString(_usageDayKey) == _dateKey(_now());

  DateTime get startedAt {
    final saved = _prefs.getString(_startedAtKey);
    return saved == null ? _now() : DateTime.parse(saved);
  }

  /// Today first, then each earlier day that was actually measured, at most
  /// [historyDays] entries.
  ///
  /// Days the courier never opened the app are simply absent rather than
  /// listed as zero — nothing was measured on them, and a row of zeroes would
  /// claim otherwise.
  List<DailyUsage> get history {
    final today = _dateKey(_now());
    final entries = <DailyUsage>[
      DailyUsage(date: today, mobileBytes: mobileBytes, wifiBytes: wifiBytes),
      for (final entry in _storedHistory.entries)
        if (entry.key != today)
          DailyUsage(
            date: entry.key,
            mobileBytes: entry.value.$1,
            wifiBytes: entry.value.$2,
          ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return entries.length > historyDays
        ? entries.sublist(0, historyDays)
        : entries;
  }

  /// The most recent measured day before today, or null when there is none.
  DailyUsage? get yesterday {
    final earlier = history.skip(1);
    return earlier.isEmpty ? null : earlier.first;
  }

  int get monthMobileBytes =>
      history.fold(0, (sum, day) => sum + day.mobileBytes);
  int get monthWifiBytes => history.fold(0, (sum, day) => sum + day.wifiBytes);
  int get monthBytes => monthMobileBytes + monthWifiBytes;

  /// Stored as `{"2026-09-12": [mobile, wifi]}` — one small JSON string
  /// rather than three keys per day, so pruning is a single write.
  Map<String, (int, int)> get _storedHistory {
    final raw = _prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is List && (entry.value as List).length == 2)
            entry.key as String: (
              ((entry.value as List)[0] as num).toInt(),
              ((entry.value as List)[1] as num).toInt(),
            ),
      };
    } catch (error) {
      // Corrupt history is not worth crashing over, and not worth keeping.
      if (kDebugMode) debugPrint('[DataUsage] history unreadable: $error');
      return {};
    }
  }

  Future<void> _writeHistory(Map<String, (int, int)> history) {
    return _prefs.setString(
      _historyKey,
      jsonEncode({
        for (final entry in history.entries)
          entry.key: [entry.value.$1, entry.value.$2],
      }),
    );
  }

  Future<void> start() async {
    await _rollOverIfNeeded();
    _prefs.setString(_startedAtKey, startedAt.toIso8601String());
    await sample();
    _timer ??= Timer.periodic(const Duration(minutes: 1), (_) => sample());
  }

  /// Samples the OS counter. A single minute timer is enough because the OS
  /// total is cumulative; it does not generate any network traffic itself.
  Future<void> sample() async {
    if (!_supported || _sampling) return;
    _sampling = true;
    try {
      await _rollOverIfNeeded();
      final stats = await _channel.invokeMapMethod<String, dynamic>(
        'trafficStats',
      );
      final rx = stats?['rx'] as int?;
      final tx = stats?['tx'] as int?;
      if (rx == null || tx == null) {
        _supported = false;
        notifyListeners();
        return;
      }

      final lastRx = _prefs.getInt(_lastRxKey);
      final lastTx = _prefs.getInt(_lastTxKey);
      // A lower native counter indicates a phone reboot. The new value is the
      // app traffic since boot and should still be counted.
      final deltaRx = lastRx == null || rx < lastRx ? rx : rx - lastRx;
      final deltaTx = lastTx == null || tx < lastTx ? tx : tx - lastTx;
      await _prefs.setInt(_lastRxKey, rx);
      await _prefs.setInt(_lastTxKey, tx);

      final delta = deltaRx + deltaTx;
      if (delta <= 0) return;

      final networkType = await _channel.invokeMethod<String>('networkType');
      final key = networkType == 'wifi' ? _wifiBytesKey : _mobileBytesKey;
      await _prefs.setInt(key, (_prefs.getInt(key) ?? 0) + delta);
      notifyListeners();
    } on MissingPluginException {
      // iOS does not expose a public per-app byte counter equivalent to
      // Android TrafficStats, so the UI clearly says the value is unavailable.
      _supported = false;
      notifyListeners();
    } catch (error) {
      if (kDebugMode) debugPrint('[DataUsage] sample failed: $error');
    } finally {
      _sampling = false;
    }
  }

  /// Clears today's counters *and* the stored month — "reset" on this screen
  /// has always meant "start counting from zero", and leaving a month of
  /// history behind a zeroed total would read as a bug.
  Future<void> reset() async {
    await Future.wait([
      _prefs.setInt(_mobileBytesKey, 0),
      _prefs.setInt(_wifiBytesKey, 0),
      _prefs.remove(_historyKey),
      _prefs.setString(_usageDayKey, _dateKey(_now())),
      _prefs.setString(_startedAtKey, _now().toIso8601String()),
    ]);
    notifyListeners();
  }

  Future<void> _rollOverIfNeeded() async {
    final today = _dateKey(_now());
    final previousDay = _prefs.getString(_usageDayKey);
    if (previousDay == today) return;

    // Archive the day that is ending before its counters are cleared. This is
    // the only moment those numbers exist — before, they were "today"; after
    // this they are gone — so anything not written here is lost for good.
    if (previousDay != null) {
      final mobile = _prefs.getInt(_mobileBytesKey) ?? 0;
      final wifi = _prefs.getInt(_wifiBytesKey) ?? 0;
      if (mobile > 0 || wifi > 0) {
        final archive = _storedHistory..[previousDay] = (mobile, wifi);
        await _writeHistory(_pruned(archive, today));
      }
    }

    await Future.wait([
      _prefs.setInt(_mobileBytesKey, 0),
      _prefs.setInt(_wifiBytesKey, 0),
      _prefs.setString(_usageDayKey, today),
      _prefs.setString(_startedAtKey, _now().toIso8601String()),
    ]);
    notifyListeners();
  }

  /// Drops anything older than [historyDays] days before [today].
  ///
  /// Cut by date rather than by entry count: a courier who leaves the app
  /// closed for a fortnight would otherwise keep month-old days alive simply
  /// because few entries accumulated.
  static Map<String, (int, int)> _pruned(
    Map<String, (int, int)> history,
    String today,
  ) {
    final cutoff = DateTime.parse(
      today,
    ).subtract(const Duration(days: historyDays));
    return {
      for (final entry in history.entries)
        if (DateTime.tryParse(entry.key)?.isAfter(cutoff) ?? false)
          entry.key: entry.value,
    };
  }

  static String _dateKey(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < bytesPerMegabyte) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < bytesPerGigabyte) {
      return '${(bytes / bytesPerMegabyte).toStringAsFixed(2)} MB';
    }
    return '${(bytes / bytesPerGigabyte).toStringAsFixed(2)} GB';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// One measured day. [date] is `yyyy-MM-dd` in the courier's own time zone —
/// the same key the daily counters roll over on.
class DailyUsage {
  const DailyUsage({
    required this.date,
    required this.mobileBytes,
    required this.wifiBytes,
  });

  final String date;
  final int mobileBytes;
  final int wifiBytes;

  int get totalBytes => mobileBytes + wifiBytes;

  DateTime get day => DateTime.parse(date);
}
