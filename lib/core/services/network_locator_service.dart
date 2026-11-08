import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../network/api_client.dart';

/// Last-resort positioning for the moments the phone itself has none.
///
/// The phone cannot say where it is, but it can still *see* the Wi-Fi around
/// it. Those identifiers go to our own server, which looks them up with a
/// commercial provider and answers with a coordinate — the provider key never
/// leaves the server.
///
/// Order of preference, worst case last:
///   1. satellites (LocationService, high accuracy)
///   2. Android's own Wi-Fi/cell provider (LocationService, balanced)
///   3. this — a coarse fix, hundreds of metres wide, but not nothing
///
/// Android only: iOS does not let an app enumerate surrounding networks.
class NetworkLocatorService {
  NetworkLocatorService({required ApiClient api}) : _api = api;

  final ApiClient _api;

  /// Below this many visible networks a lookup is not worth the request —
  /// providers need several anchors to triangulate anything useful.
  static const int _minimumNetworks = 2;

  bool get supported => defaultTargetPlatform == TargetPlatform.android;

  Future<LatLng?> locate() async {
    if (!supported) return null;
    try {
      final networks = await _scan();
      if (networks.length < _minimumNetworks) {
        _log('only ${networks.length} network(s) visible, skipping lookup');
        return null;
      }

      final response = await _api.post(
        ApiPaths.locate,
        data: {'wifiNetworks': networks},
      );
      final code = response.statusCode ?? 0;
      final data = response.data;
      if (code < 200 || code >= 300 || data is! Map) {
        _log('locate endpoint answered HTTP $code');
        return null;
      }
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) {
        return null;
      }
      return LatLng(lat, lng);
    } catch (error) {
      // Never fatal: the courier keeps whatever position they already had.
      dev.log(
        'network positioning failed',
        name: 'NetworkLocator',
        error: error.runtimeType,
      );
      return null;
    }
  }

  Future<List<Map<String, Object>>> _scan() async {
    final can = await WiFiScan.instance.canStartScan();
    if (can != CanStartScan.yes) {
      _log('cannot scan: $can');
      return const [];
    }
    await WiFiScan.instance.startScan();
    final canGet = await WiFiScan.instance.canGetScannedResults();
    if (canGet != CanGetScannedResults.yes) {
      _log('cannot read results: $canGet');
      return const [];
    }
    final results = await WiFiScan.instance.getScannedResults();
    return results
        .where((result) => result.bssid.isNotEmpty)
        .take(30)
        .map(
          (result) => <String, Object>{
            'mac': result.bssid,
            'signalStrength': result.level,
          },
        )
        .toList();
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('\x1B[36m🔵 [NetworkLocator] $message\x1B[0m');
  }
}
