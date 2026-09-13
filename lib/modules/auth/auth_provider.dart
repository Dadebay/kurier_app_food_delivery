import 'package:flutter/foundation.dart';

import '../../core/data/auth_repository.dart';

enum AuthStage { phone, code, authenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository, {this.onSignedIn}) {
    _repository.restore();
    _stage = _repository.isSignedIn ? AuthStage.authenticated : AuthStage.phone;
    // Also fires for a session restored from storage: the FCM token can
    // rotate while the app is closed, and the backend only ever learns about
    // it from here.
    if (_stage == AuthStage.authenticated) onSignedIn?.call();
  }

  final AuthRepository _repository;

  /// Runs once the courier is authenticated. Used to hand the push token to
  /// the backend — it stores the token against the signed-in user, so it
  /// cannot be sent any earlier.
  final VoidCallback? onSignedIn;

  late AuthStage _stage;
  String _phone = '';
  bool _busy = false;
  bool _codeRejected = false;

  AuthStage get stage => _stage;
  String get phone => _phone;
  bool get busy => _busy;
  bool get codeRejected => _codeRejected;
  bool get isSignedIn => _stage == AuthStage.authenticated;

  Future<void> requestCode(String phone) async {
    _phone = phone;
    _setBusy(true);
    try {
      await _repository.requestCode(phone);
      _stage = AuthStage.code;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> verify(String code) async {
    _codeRejected = false;
    _setBusy(true);
    try {
      final ok = await _repository.verify(phone: _phone, code: code);
      if (ok) {
        _stage = AuthStage.authenticated;
        onSignedIn?.call();
      } else {
        _codeRejected = true;
      }
      return ok;
    } finally {
      _setBusy(false);
    }
  }

  void backToPhone() {
    _stage = AuthStage.phone;
    _codeRejected = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _stage = AuthStage.phone;
    _phone = '';
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}
