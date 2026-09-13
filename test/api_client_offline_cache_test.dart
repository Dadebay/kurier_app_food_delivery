import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kurier_app/core/network/api_client.dart';

/// Serves a canned body on its first call for a given path, then throws a
/// connection-level [DioException] (no response at all) on every call after
/// that — standing in for "had signal once, lost it since".
class _FlakyAdapter implements HttpClientAdapter {
  final Map<String, int> _callsByPath = {};
  final Map<String, Object> _bodyByPath = {};

  void respondOnceWith(String path, Object body) => _bodyByPath[path] = body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final calls = (_callsByPath[path] ?? 0) + 1;
    _callsByPath[path] = calls;

    if (calls == 1 && _bodyByPath.containsKey(path)) {
      final bytes = utf8.encode(jsonEncode(_bodyByPath[path]));
      return ResponseBody.fromBytes(
        bytes,
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    throw DioException.connectionError(
      requestOptions: options,
      reason: 'simulated signal loss',
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('api_cache_test');
    // ApiClient's HiveCacheStore needs a home directory — main.dart gets
    // this for free from TileCacheService's own HiveCacheStore running
    // first; a plain test has to set it up itself.
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    tempDir.deleteSync(recursive: true);
  });

  test('a GET already fetched once stays available once offline', () async {
    final api = ApiClient();
    final adapter = _FlakyAdapter();
    api.raw.httpClientAdapter = adapter;
    adapter.respondOnceWith('orders', {
      'items': [
        {'id': 'o1'},
      ],
      'pages': 1,
    });

    final first = await api.get('orders');
    expect(first.statusCode, 200);

    // The adapter now throws on every call — this can only succeed if the
    // cache interceptor served the cached copy instead of the network.
    final second = await api.get('orders');
    expect(second.data, first.data);
  });

  test('a path never fetched while online still fails offline', () async {
    final api = ApiClient();
    api.raw.httpClientAdapter = _FlakyAdapter();

    expect(api.get('orders'), throwsA(isA<DioException>()));
  });

  test('clearCache drops matching entries so they miss again', () async {
    final api = ApiClient();
    final adapter = _FlakyAdapter();
    api.raw.httpClientAdapter = adapter;
    adapter.respondOnceWith('orders', {
      'items': [
        {'id': 'o1'},
      ],
    });

    final cached = await api.get('orders');
    expect(cached.statusCode, 200);

    await api.clearCache(RegExp(r'/orders'));

    expect(api.get('orders'), throwsA(isA<DioException>()));
  });

  test('clearCache leaves entries outside the pattern untouched', () async {
    final api = ApiClient();
    final adapter = _FlakyAdapter();
    api.raw.httpClientAdapter = adapter;
    adapter.respondOnceWith('branches', [
      {'id': 'b1', 'isPrimary': true},
    ]);
    adapter.respondOnceWith('orders', {'items': []});

    await api.get('branches');
    await api.get('orders');

    // Sign-out clears only the courier's own deliveries — the branch list
    // must still answer offline afterwards.
    await api.clearCache(RegExp(r'/orders'));

    final branches = await api.get('branches');
    expect(branches.data, [
      {'id': 'b1', 'isPrimary': true},
    ]);
    expect(api.get('orders'), throwsA(isA<DioException>()));
  });
}
