import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_config.dart';
import '../network/api_client.dart';

/// Thrown when the backend rejects an OTP request, e.g. rate-limiting a
/// courier who taps "get code" repeatedly.
class OtpRequestException implements Exception {
  const OtpRequestException(this.statusCode);

  final int? statusCode;

  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'OtpRequestException: HTTP $statusCode';
}

/// Phone + SMS code sign-in, the same scheme the customer app uses (slide 5) —
/// no passwords for anyone in the field.
class AuthRepository {
  AuthRepository({required ApiClient api, required SharedPreferences prefs})
    : _api = api,
      _prefs = prefs;

  static const String _tokenKey = 'courier_token';
  static const String _phoneKey = 'courier_phone';
  static const String _refreshTokenKey = 'courier_refresh_token';
  static const String _demoCode = '000000';

  final ApiClient _api;
  final SharedPreferences _prefs;

  String? get token => _prefs.getString(_tokenKey);
  bool get isSignedIn => token != null;

  /// The phone number that was verified at sign-in. In demo mode this is the
  /// only thing standing in for a real backend record, so the mock courier
  /// profile can be derived from it instead of showing a fixed name.
  String? get signedInPhone => _prefs.getString(_phoneKey);

  /// Restores the saved session into the HTTP client on app start.
  void restore() {
    _api.accountId = token == null ? null : signedInPhone;
    _api.token = token;
  }

  Future<void> requestCode(String phone) async {
    if (AppConfig.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return;
    }
    final response = await _api.post(
      ApiPaths.requestCode,
      data: {'phone': phone},
    );
    if (response.statusCode != 200) {
      throw OtpRequestException(response.statusCode);
    }

    // The local development API intentionally returns devCode. Never show it
    // in the UI or emit it from release builds.
    if (kDebugMode && response.data is Map<String, dynamic>) {
      final devCode = (response.data as Map<String, dynamic>)['devCode'];
      if (devCode is String && devCode.isNotEmpty) {
        _printDevCode(phone: phone, code: devCode);
      }
    }
  }

  /// Debug-only terminal output, styled to stand out from normal Flutter logs.
  /// This is never called in release mode and never renders inside the app.
  void _printDevCode({required String phone, required String code}) {
    const green = '\x1B[1;32m';
    const yellow = '\x1B[1;33m';
    const cyan = '\x1B[1;36m';
    const reset = '\x1B[0m';
    const width = 40;
    final line = '═' * width;
    final phoneText = ' PHONE: $phone';
    final codeText = ' OTP CODE: $code';
    debugPrint('$green╔$line╗$reset');
    debugPrint(
      '$green║$reset$cyan$phoneText$reset${' ' * (width - phoneText.length)}$green║$reset',
    );
    debugPrint(
      '$green║$reset$yellow$codeText$reset${' ' * (width - codeText.length)}$green║$reset',
    );
    debugPrint('$green╚$line╝$reset');
  }

  /// Returns `true` when the code was accepted and the session is stored.
  Future<bool> verify({required String phone, required String code}) async {
    if (AppConfig.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (code != _demoCode) return false;
      await _persist(token: 'demo-token', phone: phone, refreshToken: null);
      return true;
    }

    final response = await _api.post(
      ApiPaths.verifyCode,
      data: {'phone': phone, 'code': code},
    );
    if (response.statusCode != 200) {
      if (kDebugMode) {
        _printVerifyError(response.statusCode, response.data);
      }
      return false;
    }

    final payload = response.data as Map<String, dynamic>;
    final user = payload['user'] as Map<String, dynamic>?;
    if (user?['role'] != 'COURIER') {
      if (kDebugMode) {
        debugPrint('[OTP] Verify failed: account is not a courier.');
      }
      return false;
    }

    final token = payload['accessToken'] as String?;
    if (token == null) {
      if (kDebugMode) {
        debugPrint('[OTP] Verify failed: access token missing.');
      }
      return false;
    }

    await _persist(
      token: token,
      phone: phone,
      refreshToken: payload['refreshToken'] as String?,
    );
    return true;
  }

  void _printVerifyError(int? statusCode, dynamic body) {
    final message = body is Map<String, dynamic> ? body['message'] : body;
    const red = '\x1B[1;31m';
    const yellow = '\x1B[1;33m';
    const reset = '\x1B[0m';
    debugPrint('$red╔════════ OTP VERIFY FAILED ════════╗$reset');
    debugPrint('$red║$reset HTTP: $yellow$statusCode$reset');
    debugPrint('$red║$reset ${message ?? 'Unknown error'}');
    debugPrint('$red╚══════════════════════════════════╝$reset');
  }

  Future<void> signOut() async {
    final refreshToken = _prefs.getString(_refreshTokenKey);
    try {
      if (!AppConfig.useMockData && refreshToken != null) {
        await _api.post(ApiPaths.logout, data: {'refreshToken': refreshToken});
      }
    } finally {
      await _clearSession();
    }
  }

  Future<bool> refreshSession() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool>? _refreshInFlight;

  Future<bool> _doRefresh() async {
    final generation = _api.sessionGeneration;
    final refreshToken = _prefs.getString(_refreshTokenKey);
    if (refreshToken == null) return false;
    try {
      final response = await _api.post(
        ApiPaths.refresh,
        data: {'refreshToken': refreshToken},
      );
      if (generation != _api.sessionGeneration) return false;
      final data = response.data;
      final token = data is Map<String, dynamic>
          ? data['accessToken'] as String?
          : null;
      if (response.statusCode != 200 || token == null) {
        if (response.statusCode == 400 || response.statusCode == 401) {
          await _clearSession();
        }
        return false;
      }
      await _persist(
        token: token,
        phone: signedInPhone ?? '',
        refreshToken: data['refreshToken'] as String?,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persist({
    required String token,
    required String phone,
    required String? refreshToken,
  }) async {
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_phoneKey, phone);
    if (refreshToken != null) {
      await _prefs.setString(_refreshTokenKey, refreshToken);
    }
    _api.accountId = phone;
    _api.token = token;
  }

  /// Matches every courier-specific GET the app caches for offline viewing —
  /// assigned deliveries, which carry customer names, addresses and phone
  /// numbers. Not the branch list, which is public and stays cached across
  /// couriers on a shared device.
  static final _personalCachePaths = RegExp(r'/orders');

  Future<void> _clearSession() async {
    _api.accountId = null;
    _api.token = null;
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_phoneKey);
    await _prefs.remove(_refreshTokenKey);
    _api.token = null;
    await _api.clearCache(_personalCachePaths);
  }
}
