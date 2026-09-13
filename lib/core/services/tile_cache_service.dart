import 'dart:developer' as dev;

import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_config.dart';

/// Disk cache for the map tiles served by our own tile server.
///
/// Two reasons this matters for a courier app:
///  * the internet in Ashgabat is slow — a cached district opens instantly;
///  * when the signal drops mid-delivery the map keeps drawing instead of
///    turning into a grey grid.
///
/// [CachedTileProvider] handles the cancel-during-pan case itself: a cancelled
/// tile returns a transparent image and is *not* written to the cache, so a
/// partial response can never get stuck there as a permanent grey square.
class TileCacheService {
  const TileCacheService._();

  static late final HiveCacheStore _store;
  static late final CachedTileProvider tileProvider;
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;

    // Application support survives OS clean-ups; the temp dir does not.
    final dir = await getApplicationSupportDirectory();
    final cachePath = join(dir.path, 'map_tile_cache');

    _store = HiveCacheStore(cachePath, hiveBoxName: 'map_tile_cache');

    tileProvider = CachedTileProvider(
      store: _store,
      maxStale: AppConfig.tileCacheMaxStale,
      // Always prefer the cached tile — this is what gives offline maps.
      cachePolicy: CachePolicy.forceCache,
      // Empty list = fall back to the cache on *any* network error.
      hitCacheOnErrorExcept: const [],
    );

    _ready = true;
    dev.log('initialized at $cachePath', name: 'TileCacheService');
  }

  /// Manual "clear map cache" action in the profile screen.
  static Future<void> clear() async {
    await _store.clean();
    dev.log('cache cleared', name: 'TileCacheService');
  }
}
