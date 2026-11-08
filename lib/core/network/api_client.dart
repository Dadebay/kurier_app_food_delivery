import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';

import '../constants/app_config.dart';

/// Thin Dio wrapper. Timeouts are deliberately generous — a courier on a weak
/// 3G cell should get a slow answer rather than a false failure.
class ApiClient {
  ApiClient() {
    // `directory: null` — Hive is already pointed at its home directory by
    // `Hive.initFlutter()`/`TileCacheService` before this runs; calling
    // `Hive.init()` again here with a second path would silently move
    // *every* box (tiles included) to wherever was initialized last.
    _cacheStore = HiveCacheStore(null, hiveBoxName: _cacheBoxName);

    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 25),
        headers: const {'Accept': 'application/json'},
        // We inspect status codes ourselves so 4xx does not throw.
        validateStatus: (code) => code != null && code < 500,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          final alreadyRetried =
              response.requestOptions.extra['retried'] == true;
          final isRefreshCall =
              response.requestOptions.path == ApiPaths.refresh;
          if (response.statusCode == 401 &&
              !alreadyRetried &&
              !isRefreshCall &&
              onUnauthorized != null) {
            final refreshed = await onUnauthorized!();
            if (refreshed) {
              final retried = await _dio.fetch<dynamic>(
                response.requestOptions..extra['retried'] = true,
              );
              return handler.resolve(retried);
            }
          }
          handler.next(response);
        },
        onError: (error, handler) {
          dev.log(
            '${error.requestOptions.method} ${error.requestOptions.path} → '
            '${error.type.name}',
            name: 'ApiClient',
          );
          handler.next(error);
        },
      ),
    );

    // Added last so it sees the *final* response/error — after the 401
    // refresh-and-retry above has already had its say — and only ever
    // touches GET requests (dio_cache_interceptor skips every other verb by
    // default), so status transitions and everything else `OfflineQueueService`
    // sends never risk being served from a stale copy. On a real request
    // failure (dead zone, lift, tunnel) this hands back whichever response
    // it last cached instead of throwing, so the assigned route and branch
    // stay visible without a connection — `CourierRepository` needs no
    // offline-specific read code of its own because the failure never
    // reaches it. This is a separate concern from `OfflineQueueService`,
    // which queues *writes*; this only ever answers reads.
    _dio.interceptors.add(
      DioCacheInterceptor(
        options: CacheOptions(
          store: _cacheStore,
          policy: CachePolicy.refreshForceCache,
          maxStale: AppConfig.apiCacheMaxStale,
          hitCacheOnErrorExcept: const [],
        ),
      ),
    );
  }

  static const String _cacheBoxName = 'api_response_cache';

  late final Dio _dio;
  late final HiveCacheStore _cacheStore;
  String? _token;

  /// Refreshes an expired access token before retrying a protected request.
  Future<bool> Function()? onUnauthorized;

  set token(String? value) => _token = value;

  Dio get raw => _dio;

  /// Drops cached GET responses whose path matches [pathPattern] — call on
  /// sign-out so the next courier on this device can't see the previous
  /// courier's cached deliveries (customer names, addresses, phone numbers)
  /// before their own first successful fetch.
  Future<void> clearCache(RegExp pathPattern) =>
      _cacheStore.deleteFromPath(pathPattern);

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _dio.get(path, queryParameters: query);

  Future<Response<dynamic>> post(String path, {Object? data}) =>
      _dio.post(path, data: data);

  Future<Response<dynamic>> patch(String path, {Object? data}) =>
      _dio.patch(path, data: data);

  Future<Response<dynamic>> put(String path, {Object? data}) =>
      _dio.put(path, data: data);

  Future<Response<dynamic>> delete(String path, {Object? data}) =>
      _dio.delete(path, data: data);
}

/// Server paths, kept next to the client so a backend rename is a one-file
/// change.
class ApiPaths {
  const ApiPaths._();

  static const String requestCode = 'auth/otp/request';
  static const String verifyCode = 'auth/otp/verify';
  static const String refresh = 'auth/refresh';
  static const String logout = 'auth/logout';
  static const String orders = 'orders';
  static const String courierRoute = 'orders/courier/route';
  static const String branches = 'branches';
  static const String ping = 'tracking/me/location';

  /// Server-side Wi-Fi/cell positioning, used only when the phone has no fix.
  static const String locate = 'tracking/me/locate';
  static const String pushDevices = 'notifications/devices';

  static String orderStatus(String id) => 'orders/$id/transition';
}
