import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Single source of truth for "is the phone online right now".
///
/// Everything that writes to the server watches this: the offline banner on the
/// route screen, the queue flush loop and the tracking uploader.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService() {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _online = true;
  bool get online => _online;
  bool get offline => !_online;

  Future<void> _init() async {
    _apply(await _connectivity.checkConnectivity());
    _sub = _connectivity.onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    final next = results.any((r) => r != ConnectivityResult.none);
    if (next == _online) return;
    _online = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
